"""Real Mii v2 BLE hardware probe. Uses an ephemeral test identity, no USB transport."""
import asyncio
import base64
import json
import struct
import time
import uuid

from bleak import BleakClient, BleakScanner
from nacl.public import PrivateKey, PublicKey, SealedBox
from nacl.signing import SigningKey, VerifyKey

SERVICE = 'c0a80101-7d2b-4e18-9bf0-3ae5f1002001'
RX = 'c0a80101-7d2b-4e18-9bf0-3ae5f1002002'
TX = 'c0a80101-7d2b-4e18-9bf0-3ae5f1002003'


def b64(value):
    return base64.urlsafe_b64encode(value).decode()


def packed(value):
    return json.dumps(value, ensure_ascii=False, separators=(',', ':')).encode()


async def main():
    signing, box = SigningKey.generate(), PrivateKey.generate()
    own = b64(bytes(signing.verify_key))
    peers = {}
    packets = asyncio.Queue(maxsize=128)
    assembled = bytearray()
    expected = 0
    lock = asyncio.Lock()
    receipt, reply = asyncio.Event(), asyncio.Event()
    sent_id = str(uuid.uuid4())

    def create(destination, kind, payload, mid=None):
        fields = [2, mid or str(uuid.uuid4()), own, destination, int(time.time()*1000), kind, b64(payload), 7]
        return packed(fields + [b64(signing.sign(packed(fields)).signature), 0])

    def notification(_, frame):
        nonlocal expected
        if not 5 <= len(frame) <= 20:
            return
        index, total = struct.unpack('>HH', frame[:4])
        if index == 0:
            assembled.clear()
            expected = 0
        if index != expected or not 1 <= total <= 512:
            assembled.clear()
            expected = 0
            return
        assembled.extend(frame[4:])
        expected += 1
        if len(assembled) > 8192:
            assembled.clear()
            expected = 0
            return
        if expected == total:
            if not packets.full():
                packets.put_nowait(bytes(assembled))
            assembled.clear()
            expected = 0

    devices = await BleakScanner.discover(timeout=10, service_uuids=[SERVICE])
    if len(devices) != 1:
        raise RuntimeError(f'Expected one mesh phone for this probe, found {len(devices)}')
    async with BleakClient(devices[0], timeout=30) as client:
        async def write(packet):
            async with lock:
                count = (len(packet)+15)//16
                for i in range(count):
                    await client.write_gatt_char(RX, struct.pack('>HH', i, count)+packet[i*16:(i+1)*16], response=True)

        async def announce():
            while True:
                await write(create('*', 'presence', packed(['Laptop mesh test', b64(bytes(box.public_key))])))
                await asyncio.sleep(15)

        async def receive():
            while True:
                packet = await packets.get()
                try:
                    a = json.loads(packet)
                    if len(a) != 10 or a[0] != 2 or a[7] != 7 or not 0 <= a[9] <= 7:
                        raise ValueError('Header')
                    VerifyKey(base64.urlsafe_b64decode(a[2])).verify(packed(a[:8]), base64.urlsafe_b64decode(a[8]))
                    if abs(time.time()*1000-a[4]) > 86400000:
                        raise ValueError('Expired')
                    payload = base64.urlsafe_b64decode(a[6])
                    if a[5] == 'presence':
                        name, key = json.loads(payload)
                        peers[a[2]] = key
                        print('SIGNED_PEER_DISCOVERED:', name, flush=True)
                    elif a[3] == own:
                        kind, body, reference = json.loads(SealedBox(box).decrypt(payload))
                        if kind == 'ack' and reference == sent_id:
                            receipt.set()
                            print('PHONE_PERSISTED_RECEIPT_VERIFIED', flush=True)
                        elif kind in ('text', 'sticker', 'reaction'):
                            print('PHONE_ENCRYPTED_MESSAGE:', kind, body, flush=True)
                            key = peers.get(a[2])
                            if key:
                                ack = SealedBox(PublicKey(base64.urlsafe_b64decode(key))).encrypt(packed(['ack', '', a[1]]))
                                await write(create(a[2], 'sealed', ack))
                            if body == 'Mesh reply verified':
                                reply.set()
                except Exception as error:
                    print('REJECTED:', type(error).__name__, flush=True)

        await client.start_notify(TX, notification)
        worker = asyncio.create_task(receive())
        beacon = asyncio.create_task(announce())
        try:
            async with asyncio.timeout(60):
                while not peers:
                    await asyncio.sleep(.2)
            peer, key = next(iter(peers.items()))
            cipher = SealedBox(PublicKey(base64.urlsafe_b64decode(key))).encrypt(packed(['text', 'Automatic mesh hello from laptop', '']))
            # Retry the same signed message ID to exercise receiver dedup.
            message = create(peer, 'sealed', cipher, sent_id)
            for _ in range(3):
                await write(message)
                try:
                    await asyncio.wait_for(receipt.wait(), 20)
                    break
                except TimeoutError:
                    continue
            if not receipt.is_set():
                raise RuntimeError('No authenticated phone receipt')
            print('WAITING_FOR_REPLY: Mesh reply verified', flush=True)
            await asyncio.wait_for(reply.wait(), 180)
            print('MESH_REAL_BLE_ROUND_TRIP_PASS', flush=True)
        finally:
            beacon.cancel()
            worker.cancel()
            await asyncio.gather(beacon, worker, return_exceptions=True)


if __name__ == '__main__':
    asyncio.run(main())
