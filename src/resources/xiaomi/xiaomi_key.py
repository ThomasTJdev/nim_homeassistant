import sys

from Crypto.Cipher import AES

key = sys.argv[1]
token = sys.argv[2]

init_vector = bytes(bytearray.fromhex('17996d093d28ddb3ba695a2e6f58562e'))

encryptor = AES.new(key.encode(), AES.MODE_CBC, IV=init_vector)

ciphertext = encryptor.encrypt(token.encode())

realKey = ''.join('{:02x}'.format(x) for x in ciphertext)

print(realKey)