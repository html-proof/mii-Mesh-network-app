import os
import struct
import unittest
import uuid
from companion import Assembler, encode_packet, decode_packet, read_key

class ProtocolTests(unittest.TestCase):
    def test_crypto_and_direction(self):
        key = os.urandom(32)
        mid = str(uuid.uuid4())
        packet = encode_packet(key, mid, 'text', 'Hello phone', from_phone=False)
        self.assertEqual(decode_packet(key, packet, from_phone=False), (mid, 'text', 'Hello phone'))
        self.assertNotIn(b'Hello phone', packet)
        for other, wire, direction in [(os.urandom(32), packet, False), (key, packet, True), (key, packet[:-1]+bytes([packet[-1]^1]), False)]:
            with self.assertRaises(Exception): decode_packet(other, wire, direction)

    def test_frames_and_resource_bounds(self):
        data = os.urandom(4096)
        assembler = Assembler()
        result = None
        for i in range(256):
            result = assembler.feed(struct.pack('>HH', i, 256)+data[i*16:(i+1)*16])
        self.assertEqual(result, data)
        for frame in [b'bad', struct.pack('>HH', 0, 257)+b'x', struct.pack('>HH', 2, 3)+b'x']:
            with self.assertRaises(ValueError): Assembler().feed(frame)

    def test_reject_malformed_key_and_body(self):
        with self.assertRaises(Exception): read_key('bad-secret')
        with self.assertRaises(ValueError): encode_packet(os.urandom(32), str(uuid.uuid4()), 'text', 'x'*2049)

if __name__ == '__main__': unittest.main()
