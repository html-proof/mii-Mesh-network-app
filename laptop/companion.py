"""Mii Mesh direct BLE companion. No TCP, USB messaging, or cloud transport."""
import asyncio
import base64
import json
import os
import struct
import sys
import time
import uuid
from collections import OrderedDict

from bleak import BleakClient, BleakScanner
from nacl.bindings import crypto_aead_xchacha20poly1305_ietf_encrypt as encrypt
from nacl.bindings import crypto_aead_xchacha20poly1305_ietf_decrypt as decrypt

SERVICE = 'c0a80101-7d2b-4e18-9bf0-3ae5f1000001'
RX = 'c0a80101-7d2b-4e18-9bf0-3ae5f1000002'
TX = 'c0a80101-7d2b-4e18-9bf0-3ae5f1000003'


def encode_packet(key, message_id, kind, body, from_phone=False):
    nonce = os.urandom(24)
    if len(body.encode('utf-8')) > 2048:
        raise ValueError('Messages are limited to 2048 UTF-8 bytes')
    payload = json.dumps([1, message_id, kind, body, int(time.time()*1000)], ensure_ascii=False, separators=(',', ':')).encode()
    aad = b'mii-ble-v1:phone' if from_phone else b'mii-ble-v1:laptop'
    packet = b'\x01' + nonce + encrypt(payload, aad, nonce, key)
    if len(packet) > 4096:
        raise ValueError('Packet too large')
    return packet


def decode_packet(key, packet, from_phone=True):
    if not 41 <= len(packet) <= 4096 or packet[0] != 1:
        raise ValueError('Invalid packet')
    aad = b'mii-ble-v1:phone' if from_phone else b'mii-ble-v1:laptop'
    plain = decrypt(packet[25:], aad, packet[1:25], key).decode('utf-8')
    quoted = escaped = False
    depth = 0
    for char in plain:
        if escaped:
            escaped = False
            continue
        if quoted and char == '\\':
            escaped = True
            continue
        if char == '"':
            quoted = not quoted
        elif not quoted and char in '[{':
            depth += 1
            if depth > 1:
                raise ValueError('Nested packet')
        elif not quoted and char in ']}':
            depth -= 1
    a = json.loads(plain)
    if not isinstance(a, list) or len(a) != 5 or type(a[0]) is not int or a[0] != 1:
        raise ValueError('Unsupported payload')
    _, mid, kind, body, timestamp = a
    if not isinstance(mid, str) or str(uuid.UUID(mid)) != mid or kind not in ('text', 'ack') or not isinstance(body, str) or type(timestamp) is not int:
        raise ValueError('Invalid fields')
    if len(body.encode()) > 2048 or (kind == 'text' and not body.strip()) or (kind == 'ack' and body):
        raise ValueError('Invalid body')
    now = int(time.time()*1000)
    if timestamp < now - 86400000 or timestamp > now + 300000:
        raise ValueError('Expired message')
    return mid, kind, body


class Assembler:
    def __init__(self):
        self.data = bytearray()
        self.index = self.total = 0
        self.last = 0

    def feed(self, frame):
        if not 5 <= len(frame) <= 20:
            raise ValueError('Invalid frame')
        index, total = struct.unpack('>HH', frame[:4])
        now = time.monotonic()
        if index == 0:
            self.data.clear()
            self.index, self.total = 0, total
        if not 1 <= total <= 256 or index != self.index or total != self.total or (index and now - self.last > 10):
            self.data.clear()
            self.index = 0
            raise ValueError('Out-of-order frame')
        self.data.extend(frame[4:])
        self.index += 1
        self.last = now
        if len(self.data) > 4096:
            raise ValueError('Oversized packet')
        if self.index == self.total:
            packet = bytes(self.data)
            self.data.clear()
            self.index = 0
            return packet
        return None


class Link:
    def __init__(self, key, on_event):
        self.key = key
        self.on_event = on_event
        self.client = None
        self.assembler = Assembler()
        self.lock = asyncio.Lock()
        self.seen = OrderedDict()
        self.pending = {}
        self.received = asyncio.Queue(maxsize=120)
        self.worker = None

    async def connect(self):
        self.on_event('status', 'Scanning for Mii Mesh over Bluetooth…')
        devices = await BleakScanner.discover(timeout=8, service_uuids=[SERVICE])
        if not devices:
            raise RuntimeError('No Mii Mesh phone found. Open Nearby and tap Start Bluetooth.')
        if len(devices) != 1:
            raise RuntimeError('More than one Mii Mesh phone found. Stop advertising on the other phones and retry.')
        self.client = BleakClient(devices[0], disconnected_callback=lambda _: self.on_event('status', 'Bluetooth disconnected'), timeout=20)
        await self.client.connect()
        await self.client.start_notify(TX, self._notification)
        self.worker = asyncio.create_task(self._receive())
        self.on_event('status', 'Bluetooth connected. Pairing secret is checked on the first authenticated message.')

    def _notification(self, _characteristic, data):
        try:
            packet = self.assembler.feed(data)
            if packet:
                self.received.put_nowait(packet)
        except (ValueError, asyncio.QueueFull):
            self.on_event('status', 'Rejected an invalid or excessive Bluetooth frame')

    async def _receive(self):
        while True:
            packet = await self.received.get()
            try:
                mid, kind, body = decode_packet(self.key, packet)
                if kind == 'ack':
                    event = self.pending.get(mid)
                    if event:
                        event.set()
                        self.on_event('delivered', mid)
                else:
                    old = self.seen.get(mid)
                    if old is not None and old != body:
                        raise ValueError('Conflicting ID')
                    if old is None:
                        self.seen[mid] = body
                        if len(self.seen) > 1024:
                            self.seen.popitem(last=False)
                        self.on_event('message', body)
                    await self.write(encode_packet(self.key, mid, 'ack', ''))
            except Exception:
                self.on_event('status', 'Rejected message: verify the pairing secret and retry')
            finally:
                self.received.task_done()

    async def write(self, packet):
        if not self.client or not self.client.is_connected:
            raise RuntimeError('Bluetooth is disconnected')
        async with self.lock:
            total = (len(packet) + 15) // 16
            for i in range(total):
                frame = struct.pack('>HH', i, total) + packet[i*16:(i+1)*16]
                await self.client.write_gatt_char(RX, frame, response=True)

    async def send(self, body):
        if not body.strip():
            raise ValueError('Enter a message')
        mid = str(uuid.uuid4())
        event = asyncio.Event()
        self.pending[mid] = event
        try:
            await self.write(encode_packet(self.key, mid, 'text', body))
            await asyncio.wait_for(event.wait(), 20)
            return mid
        finally:
            self.pending.pop(mid, None)

    async def close(self):
        if self.worker:
            self.worker.cancel()
        if self.client and self.client.is_connected:
            await self.client.disconnect()


def read_key(value):
    key = base64.b64decode(value.strip().encode(), altchars=b'-_', validate=True)
    if len(key) != 32:
        raise ValueError('Pairing secret must contain 32 random bytes')
    return key


async def hardware_test(key):
    reply = asyncio.Event()
    def event(kind, value):
        if kind == 'message':
            if value == 'Hello laptop - received on real Bluetooth':
                print('PHONE_REPLY_VERIFIED_OVER_BLE', flush=True)
                reply.set()
            else:
                print('PHONE_MESSAGE_RECEIVED_OVER_BLE', flush=True)
        elif kind == 'delivered':
            print('PHONE_AUTHENTICATED_ACK_RECEIVED_OVER_BLE', flush=True)
        else:
            print(value, flush=True)
    link = Link(key, event)
    try:
        await link.connect()
        await link.send('Hello phone - sent from this laptop over real Bluetooth')
        print('WAITING_FOR_PHONE_REPLY', flush=True)
        await asyncio.wait_for(reply.wait(), 180)
        await link.received.join()
        print('ROUND_TRIP_PASS', flush=True)
    finally:
        await link.close()


def gui():
    import threading
    import queue
    import tkinter as tk
    from tkinter import ttk, scrolledtext
    root = tk.Tk()
    root.title('Mii Mesh · Laptop Bluetooth')
    root.geometry('660x620')
    root.configure(bg='#f7f8f4')
    ui_events = queue.Queue()
    loop = asyncio.new_event_loop()
    threading.Thread(target=loop.run_forever, daemon=True).start()
    link = None
    ttk.Label(root, text='Mii Mesh · Direct Bluetooth', font=('Segoe UI', 20, 'bold')).pack(anchor='w', padx=24, pady=(22, 8))
    ttk.Label(root, text='On your phone: Nearby → Start Bluetooth → Show pairing secret.\nPaste the secret here. Keep the phone screen open.', wraplength=600).pack(anchor='w', padx=24)
    key_input = ttk.Entry(root, show='•', width=62)
    key_input.pack(fill='x', padx=24, pady=12)
    status = tk.StringVar(value='Not connected · no internet or USB messaging')
    ttk.Label(root, textvariable=status, wraplength=600).pack(anchor='w', padx=24, pady=8)
    transcript = scrolledtext.ScrolledText(root, state='disabled', font=('Segoe UI', 11), wrap='word')
    transcript.pack(fill='both', expand=True, padx=24, pady=10)
    message = ttk.Entry(root, font=('Segoe UI', 12))
    message.pack(fill='x', padx=24, pady=8)
    controls = ttk.Frame(root)
    controls.pack(fill='x', padx=24, pady=12)
    def append(text):
        transcript.configure(state='normal'); transcript.insert('end', text+'\n\n'); transcript.see('end'); transcript.configure(state='disabled')
    def task(coro):
        def done(future):
            try:
                future.result()
            except Exception as error:
                ui_events.put(('status', 'Action failed: '+str(error)))
        asyncio.run_coroutine_threadsafe(coro, loop).add_done_callback(done)
    def connect():
        nonlocal link
        try:
            key = read_key(key_input.get())
        except Exception:
            status.set('Enter the complete pairing secret shown on your phone.'); return
        async def reconnect():
            nonlocal link
            if link:
                await link.close()
            link = Link(key, lambda k, v: ui_events.put((k, v)))
            await link.connect()
        task(reconnect())
    def send():
        body = message.get().strip()
        if not body or not link:
            status.set('Connect to your phone and enter a message first.'); return
        message.delete(0, 'end')
        append('You: '+body)
        task(link.send(body))
    ttk.Button(controls, text='Connect Bluetooth', command=connect).pack(side='left')
    ttk.Button(controls, text='Send message', command=send).pack(side='right')
    message.bind('<Return>', lambda _: send())
    def poll():
        while not ui_events.empty():
            kind, value = ui_events.get_nowait()
            if kind == 'message':
                append('Phone: '+value)
            elif kind == 'delivered':
                status.set('Delivered · phone authenticated and saved your message')
            else:
                status.set(value)
        root.after(100, poll)
    def close():
        if link:
            asyncio.run_coroutine_threadsafe(link.close(), loop)
        root.destroy()
    root.protocol('WM_DELETE_WINDOW', close)
    poll(); root.mainloop()


if __name__ == '__main__':
    if '--test' in sys.argv:
        # Secret comes from stdin, never command-line arguments or logs.
        asyncio.run(hardware_test(read_key(sys.stdin.readline())))
    elif '--scan' in sys.argv:
        async def scan():
            devices = await BleakScanner.discover(timeout=8, service_uuids=[SERVICE])
            print('Mii Mesh advertisers found:', len(devices))
        asyncio.run(scan())
    else:
        gui()
