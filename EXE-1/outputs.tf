output "tls_private_key" {
  value = nonsensitive(tls_private_key.rajtestvm_ssh.private_key_pem)
}