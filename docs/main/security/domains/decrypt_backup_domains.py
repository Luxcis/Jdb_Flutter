import hashlib, base64, json
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives import padding

# APK 签名证书 DER 前5字符
secret = "30820"
key_md5 = hashlib.md5(secret.encode()).hexdigest()
key_bytes = [ord(c) for c in key_md5]

# 解密函数（同 gen_signature.py 的 getDecryptString）
def decrypt(b64_encrypted):
    encrypted = json.loads(base64.b64decode(b64_encrypted))
    raw = ''.join(
        chr(encrypted[i] - key_bytes[min(i, 31)])
        for i in range(len(encrypted))
    )
    return base64.b64decode(raw).decode()

# IV 解密使用 "astarte" 作为密钥
def decrypt_iv(b64_encrypted):
    iv_md5 = hashlib.md5("astarte".encode()).hexdigest()
    iv_bytes = [ord(c) for c in iv_md5]
    encrypted = json.loads(base64.b64decode(b64_encrypted))
    raw = ''.join(
        chr(encrypted[i] - iv_bytes[min(i, 31)])
        for i in range(len(encrypted))
    )
    return base64.b64decode(raw).decode()

# 从 splash_page.dart 提取的 AES 密钥/IV 加密常量
aes_key = decrypt("WzE5OSwxNjksMTYwLDE3NCwxOTksMTA2LDEyNCwxNzQsMTM4LDE3MywxNjIsMTQ5LDE5MCwxNzksMTU3LDIwNiwxMjgsMjA5LDEyNSwxNzIsMTI4LDE4MiwxNjIsMTYxXQ==")
aes_iv  = decrypt_iv("WzE1MSwxNDMsMTI3LDEwMywxOTksMTQwLDIwMCwxNjksMTU3LDE2MiwxNjUsMTAxLDE5OCwxNjMsMTc0LDE1NywyMDMsMTI1LDE1NiwxNjksMTQxLDIyMCwxMTEsMTYyXQ==")

# AES-CBC 解密
def aes_decrypt(b64_ciphertext):
    encrypted = base64.b64decode(b64_ciphertext)
    cipher = Cipher(algorithms.AES(aes_key.encode()), modes.CBC(aes_iv.encode()))
    decryptor = cipher.decryptor()
    padded = decryptor.update(encrypted) + decryptor.finalize()
    unpadder = padding.PKCS7(128).unpadder()
    plain = unpadder.update(padded) + unpadder.finalize()
    return json.loads(plain.decode())

if __name__ == '__main__':
    # 将 startup API 返回的 backup_domains_data 粘贴到此处
    text = "JCxJQTR1DerICeuy4lmmWJuj2sRqgbDdvL2Nru5I6BmGb+GmAKKAUbjeLL1r+rFeOxq+Kb3g2MOSXYpvd9dA7Pds+G6brFTtRy7EQ0s4DkIaUfAzoKgMWldPRI/0IvUjOvVkn1t0/nUIEz2LTWmcKx5sj3BVtIV5XEiRtS8fUGvVSddw6Fy7g9nJ/iN5OxFCypbRPK0dd6+09Vx3ALU/9kI39VeBlNZE7/Vjnr2nc0MZg3PIZHCt9dlldO9uS7GMLU+LHXFq29VbyGGkXxlOuO+dE4ejYK1CJ9Qx14FuR1xWx3p8rOHo1INDE7LmqgZy/3vDlRY8hHbdDr81tKWBAS/PXcOakVZGNuEiOf6OKtQR9J3M44MUStw+k5AZ9jh0KhblvYeTdA79l1b+byubUqyDLP5XiEkyT2yQ8JTB/wHfH6Otg5/5NoI22nODaQjKUaFDDnzr0S2Vwbp0uu68GAov458mHuuIUleBSI4TGqA="

    result = aes_decrypt(text)
    print(json.dumps(result, ensure_ascii=False, indent=2))
