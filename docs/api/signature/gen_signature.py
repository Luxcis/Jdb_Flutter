import hashlib, base64, json, time

# APK 签名证书在 original/META-INF/CERT.RSA
# openssl pkcs7 -in original/META-INF/CERT.RSA -inform DER -print_certs | openssl x509 -outform DER | xxd | head
# 密钥：APK 证书 DER 前5字符
secret = "30820"
key_md5 = hashlib.md5(secret.encode()).hexdigest()
# = "da97c8240e2ad99a2d331eed95c411f5"

key_bytes = [ord(c) for c in key_md5]

# 解密函数
def decrypt(b64_encrypted):
    encrypted = json.loads(base64.b64decode(b64_encrypted))
    raw = ''.join(
        chr(encrypted[i] - key_bytes[min(i, 31)])
        for i in range(len(encrypted))
    )
    return base64.b64decode(raw).decode()  # 双重解码！

# 从 app 中提取的两个加密常量
part1 = decrypt("WzE3OCwyMTksMTI3LDE2MSwxODksMTYyLDEyMywxMDMsMTM3LDIxMCwxMjMsMjE5LDE4OSwxNzksMTIzLDIwMiwxMzksMTUwLDEzMywxNjAsMTI2LDIwNywxNjYsMTUxLDE0NiwxNTksMTg4LDEwMCwxMzgsMTM2LDE3NiwxNjEsMTQyLDEwMywxMzUsMTYwLDE0MiwxNzUsMTYwLDEwNCwxMzAsMTIxLDExOCwxMDYsMTMyLDEyNCwxMzAsMTA0LDEzMSwxMjEsMTI2LDE3MywxNDMsMTQwLDEzOCwxMDQsMTMwLDE1OSwxMTgsMTc1LDE0MiwxNTksMTYxLDE1OSwxNDMsMTI0LDEyMywxNjEsMTMxLDEzNywxMzQsMTAxLDEzMSwxNzUsMTU2LDEwMSwxMzEsMTc1LDE1NywxNTcsMTMwLDEzNywxNjAsMTA2LDE0MywxMzcsMTUzLDE2MCwxMzEsMTQwLDEyMiwxMDMsMTQzLDEzNywxMjMsMTU3LDEzMSwxMzcsMTUyLDEwMywxMzIsMTM3LDEyMiwxNzMsMTMwLDE1OSwxMzEsMTU5LDEzMCwxNDAsMTIyLDEwNiwxMzAsMTc1LDEyMywxNTksMTMwLDEyMSwxMzgsMTA0LDEzMiwxMjEsMTM0LDE3NCwxNDMsMTYyLDEyNiwxMDQsMTMwLDEwMywxMjcsMTU3LDEzMCwxMDMsMTI2LDE3NSwxNDIsMTc1LDE1NiwxNzUsMTQyLDE2MiwxMzEsMTYwLDEzMSwxNTksMTYxLDE1OSwxMzAsMTM3LDE1MywxNTksMTQyLDEwMywxNDIsMTczLDEzMSwxNzUsMTM0LDE3MiwxMzIsMTIxLDEyMywxNjEsMTMwLDEwMywxMzQsMTA1LDE0MiwxNDAsMTIyLDExNF0=")
# = "71cf27bb3c0bcdf207b64abe..."（128字符十六进制）

part2 = decrypt("WzE5OCwxNjksMTIzLDEwNiwxNzcsMTY2LDE0MCwxNjIsMTQ3LDE4OSwxNjIsMjE5LDE5OSwxMjIsMTE4LDE1OF0=")
# = "lpw6vgqzsp"

# 生成签名
def make_signature():
    ts = int(time.time())
    md5_hash = hashlib.md5(f"{ts}{part1}".encode()).hexdigest()
    return f"{ts}.{part2}.{md5_hash}"

# 示例输出：
# 1773580816.lpw6vgqzsp.6458561b88939e2093aff60948b58b86
if __name__ == '__main__':
    print(make_signature())