# nDPI Security Risk Library

This file contains ready-to-copy alert rules for every risk factor supported by your current `ndpi.so` plugin.

## Instructions

1. **Copy** the rule line you want.
2. **Paste** it into your `rules/route10-ndpi-security.rules` file.
3. **Apply** the changes by running:
   ```bash
   /bin/ash runner.sh apply
   ```

## Supported Risks

| Risk Code | Severity | Description | Suricata Rule |
| :--- | :--- | :--- | :--- |
| NDPI_URL_POSSIBLE_XSS | Severe | XSS Attack | `alert ip any any <> any any (msg:"Route10 nDPI security: XSS attack"; ndpi-risk:NDPI_URL_POSSIBLE_XSS; sid:2920101; rev:1;)` |
| NDPI_URL_POSSIBLE_SQL_INJECTION | Severe | SQL Injection | `alert ip any any <> any any (msg:"Route10 nDPI security: SQL injection"; ndpi-risk:NDPI_URL_POSSIBLE_SQL_INJECTION; sid:2920102; rev:1;)` |
| NDPI_URL_POSSIBLE_RCE_INJECTION | Severe | RCE Injection | `alert ip any any <> any any (msg:"Route10 nDPI security: RCE injection"; ndpi-risk:NDPI_URL_POSSIBLE_RCE_INJECTION; sid:2920103; rev:1;)` |
| NDPI_BINARY_APPLICATION_TRANSFER | Severe | Binary App Transfer | `alert ip any any <> any any (msg:"Route10 nDPI security: binary app transfer"; ndpi-risk:NDPI_BINARY_APPLICATION_TRANSFER; sid:2920104; rev:1;)` |
| NDPI_KNOWN_PROTOCOL_ON_NON_STANDARD_PORT | Medium | Known Proto on Non Std Port | `alert ip any any <> any any (msg:"Route10 nDPI security: non-standard port"; ndpi-risk:NDPI_KNOWN_PROTOCOL_ON_NON_STANDARD_PORT; sid:2920105; rev:1;)` |
| NDPI_TLS_SELFSIGNED_CERTIFICATE | High | Self-signed Cert | `alert ip any any <> any any (msg:"Route10 nDPI security: self-signed TLS cert"; ndpi-risk:NDPI_TLS_SELFSIGNED_CERTIFICATE; sid:2920106; rev:1;)` |
| NDPI_TLS_OBSOLETE_VERSION | High | Obsolete TLS (v1.1 or older) | `alert ip any any <> any any (msg:"Route10 nDPI security: obsolete TLS version"; ndpi-risk:NDPI_TLS_OBSOLETE_VERSION; sid:2920107; rev:1;)` |
| NDPI_TLS_WEAK_CIPHER | High | Weak TLS Cipher | `alert ip any any <> any any (msg:"Route10 nDPI security: weak TLS cipher"; ndpi-risk:NDPI_TLS_WEAK_CIPHER; sid:2920108; rev:1;)` |
| NDPI_TLS_CERTIFICATE_EXPIRED | High | TLS Cert Expired | `alert ip any any <> any any (msg:"Route10 nDPI security: TLS cert expired"; ndpi-risk:NDPI_TLS_CERTIFICATE_EXPIRED; sid:2920109; rev:1;)` |
| NDPI_TLS_CERTIFICATE_MISMATCH | High | TLS Cert Mismatch | `alert ip any any <> any any (msg:"Route10 nDPI security: TLS cert mismatch"; ndpi-risk:NDPI_TLS_CERTIFICATE_MISMATCH; sid:2920110; rev:1;)` |
| NDPI_HTTP_SUSPICIOUS_USER_AGENT | High | HTTP Susp User-Agent | `alert ip any any <> any any (msg:"Route10 nDPI security: suspicious user-agent"; ndpi-risk:NDPI_HTTP_SUSPICIOUS_USER_AGENT; sid:2920111; rev:1;)` |
| NDPI_NUMERIC_IP_HOST | Low | Numeric Hostname/SNI | `alert ip any any <> any any (msg:"Route10 nDPI security: numeric hostname"; ndpi-risk:NDPI_NUMERIC_IP_HOST; sid:2920112; rev:1;)` |
| NDPI_HTTP_SUSPICIOUS_URL | High | HTTP Susp URL | `alert ip any any <> any any (msg:"Route10 nDPI security: suspicious URL"; ndpi-risk:NDPI_HTTP_SUSPICIOUS_URL; sid:2920113; rev:1;)` |
| NDPI_HTTP_SUSPICIOUS_HEADER | High | HTTP Susp Header | `alert ip any any <> any any (msg:"Route10 nDPI security: suspicious HTTP header"; ndpi-risk:NDPI_HTTP_SUSPICIOUS_HEADER; sid:2920114; rev:1;)` |
| NDPI_TLS_NOT_CARRYING_HTTPS | Low | TLS Not Carrying HTTPS | `alert ip any any <> any any (msg:"Route10 nDPI security: TLS not HTTPS"; ndpi-risk:NDPI_TLS_NOT_CARRYING_HTTPS; sid:2920115; rev:1;)` |
| NDPI_SUSPICIOUS_DGA_DOMAIN | High | Susp DGA Domain name | `alert ip any any <> any any (msg:"Route10 nDPI security: DGA domain"; ndpi-risk:NDPI_SUSPICIOUS_DGA_DOMAIN; sid:2920116; rev:1;)` |
| NDPI_MALFORMED_PACKET | Low | Malformed Packet | `alert ip any any <> any any (msg:"Route10 nDPI security: malformed packet"; ndpi-risk:NDPI_MALFORMED_PACKET; sid:2920117; rev:1;)` |
| NDPI_SSH_OBSOLETE_CLIENT_VERSION_OR_CIPHER | High | SSH Obsolete Client | `alert ip any any <> any any (msg:"Route10 nDPI security: obsolete SSH client"; ndpi-risk:NDPI_SSH_OBSOLETE_CLIENT_VERSION_OR_CIPHER; sid:2920118; rev:1;)` |
| NDPI_SSH_OBSOLETE_SERVER_VERSION_OR_CIPHER | Medium | SSH Obsolete Server | `alert ip any any <> any any (msg:"Route10 nDPI security: obsolete SSH server"; ndpi-risk:NDPI_SSH_OBSOLETE_SERVER_VERSION_OR_CIPHER; sid:2920119; rev:1;)` |
| NDPI_SMB_INSECURE_VERSION | High | SMB Insecure Vers | `alert ip any any <> any any (msg:"Route10 nDPI security: insecure SMB version"; ndpi-risk:NDPI_SMB_INSECURE_VERSION; sid:2920120; rev:1;)` |
| NDPI_MISMATCHING_PROTOCOL_WITH_IP | High | Proto/IP Mismatch | `alert ip any any <> any any (msg:"Route10 nDPI security: protocol/IP mismatch"; ndpi-risk:NDPI_MISMATCHING_PROTOCOL_WITH_IP; sid:2920121; rev:1;)` |
| NDPI_TLS_SUSPICIOUS_ESNI_USAGE | Low | Unsafe Protocol (ESNI) | `alert ip any any <> any any (msg:"Route10 nDPI security: suspicious ESNI usage"; ndpi-risk:NDPI_TLS_SUSPICIOUS_ESNI_USAGE; sid:2920122; rev:1;)` |
| NDPI_DNS_SUSPICIOUS_TRAFFIC | Medium | Susp DNS Traffic | `alert ip any any <> any any (msg:"Route10 nDPI security: suspicious DNS"; ndpi-risk:NDPI_DNS_SUSPICIOUS_TRAFFIC; sid:2920123; rev:1;)` |
| NDPI_TLS_MISSING_SNI | Medium | Missing SNI | `alert ip any any <> any any (msg:"Route10 nDPI security: missing TLS SNI"; ndpi-risk:NDPI_TLS_MISSING_SNI; sid:2920124; rev:1;)` |
| NDPI_HTTP_SUSPICIOUS_CONTENT | High | HTTP Susp Content | `alert ip any any <> any any (msg:"Route10 nDPI security: suspicious HTTP content"; ndpi-risk:NDPI_HTTP_SUSPICIOUS_CONTENT; sid:2920125; rev:1;)` |
| NDPI_RISKY_ASN | Medium | Risky ASN | `alert ip any any <> any any (msg:"Route10 nDPI security: risky ASN"; ndpi-risk:NDPI_RISKY_ASN; sid:2920126; rev:1;)` |
| NDPI_RISKY_DOMAIN | Medium | Risky Domain Name | `alert ip any any <> any any (msg:"Route10 nDPI security: risky domain"; ndpi-risk:NDPI_RISKY_DOMAIN; sid:2920127; rev:1;)` |
| NDPI_MALICIOUS_FINGERPRINT | High | Malicious Fingerprint | `alert ip any any <> any any (msg:"Route10 nDPI security: malicious fingerprint"; ndpi-risk:NDPI_MALICIOUS_FINGERPRINT; sid:2920128; rev:1;)` |
| NDPI_MALICIOUS_SHA1_CERTIFICATE | Medium | Malicious SSL Cert | `alert ip any any <> any any (msg:"Route10 nDPI security: malicious SSL cert"; ndpi-risk:NDPI_MALICIOUS_SHA1_CERTIFICATE; sid:2920129; rev:1;)` |
| NDPI_DESKTOP_OR_FILE_SHARING_SESSION | Low | Desktop/File Sharing | `alert ip any any <> any any (msg:"Route10 nDPI security: desktop/file sharing"; ndpi-risk:NDPI_DESKTOP_OR_FILE_SHARING_SESSION; sid:2920130; rev:1;)` |
| NDPI_TLS_UNCOMMON_ALPN | Medium | Uncommon TLS ALPN | `alert ip any any <> any any (msg:"Route10 nDPI security: uncommon TLS ALPN"; ndpi-risk:NDPI_TLS_UNCOMMON_ALPN; sid:2920131; rev:1;)` |
| NDPI_TLS_CERT_VALIDITY_TOO_LONG | Medium | TLS Cert Validity Too Long | `alert ip any any <> any any (msg:"Route10 nDPI security: TLS cert validity too long"; ndpi-risk:NDPI_TLS_CERT_VALIDITY_TOO_LONG; sid:2920132; rev:1;)` |
| NDPI_TLS_SUSPICIOUS_EXTENSION | High | TLS Susp Extn | `alert ip any any <> any any (msg:"Route10 nDPI security: suspicious TLS extension"; ndpi-risk:NDPI_TLS_SUSPICIOUS_EXTENSION; sid:2920133; rev:1;)` |
| NDPI_TLS_FATAL_ALERT | Low | TLS Fatal Alert | `alert ip any any <> any any (msg:"Route10 nDPI security: TLS fatal alert"; ndpi-risk:NDPI_TLS_FATAL_ALERT; sid:2920134; rev:1;)` |
| NDPI_SUSPICIOUS_ENTROPY | Low | Susp Entropy | `alert ip any any <> any any (msg:"Route10 nDPI security: suspicious entropy"; ndpi-risk:NDPI_SUSPICIOUS_ENTROPY; sid:2920135; rev:1;)` |
| NDPI_CLEAR_TEXT_CREDENTIALS | High | Clear-Text Credentials | `alert ip any any <> any any (msg:"Route10 nDPI security: clear-text credentials"; ndpi-risk:NDPI_CLEAR_TEXT_CREDENTIALS; sid:2920136; rev:1;)` |
| NDPI_DNS_LARGE_PACKET | Medium | Large DNS Packet | `alert ip any any <> any any (msg:"Route10 nDPI security: large DNS packet"; ndpi-risk:NDPI_DNS_LARGE_PACKET; sid:2920137; rev:1;)` |
| NDPI_DNS_FRAGMENTED | Medium | Fragmented DNS | `alert ip any any <> any any (msg:"Route10 nDPI security: fragmented DNS"; ndpi-risk:NDPI_DNS_FRAGMENTED; sid:2920138; rev:1;)` |
| NDPI_INVALID_CHARACTERS | High | Invalid Chars Detected | `alert ip any any <> any any (msg:"Route10 nDPI security: invalid characters"; ndpi-risk:NDPI_INVALID_CHARACTERS; sid:2920139; rev:1;)` |
| NDPI_POSSIBLE_EXPLOIT | Severe | Possible Exploit Attempt | `alert ip any any <> any any (msg:"Route10 nDPI security: possible exploit"; ndpi-risk:NDPI_POSSIBLE_EXPLOIT; sid:2920140; rev:1;)` |
| NDPI_TLS_CERTIFICATE_ABOUT_TO_EXPIRE | Medium | TLS Cert About To Expire | `alert ip any any <> any any (msg:"Route10 nDPI security: TLS cert expiring soon"; ndpi-risk:NDPI_TLS_CERTIFICATE_ABOUT_TO_EXPIRE; sid:2920141; rev:1;)` |
| NDPI_PUNYCODE_IDN | Low | IDN Domain Name | `alert ip any any <> any any (msg:"Route10 nDPI security: Punycode IDN"; ndpi-risk:NDPI_PUNYCODE_IDN; sid:2920142; rev:1;)` |
| NDPI_ERROR_CODE_DETECTED | Low | Error Code | `alert ip any any <> any any (msg:"Route10 nDPI security: error code detected"; ndpi-risk:NDPI_ERROR_CODE_DETECTED; sid:2920143; rev:1;)` |
| NDPI_HTTP_CRAWLER_BOT | Low | Crawler/Bot | `alert ip any any <> any any (msg:"Route10 nDPI security: crawler/bot"; ndpi-risk:NDPI_HTTP_CRAWLER_BOT; sid:2920144; rev:1;)` |
| NDPI_ANONYMOUS_SUBSCRIBER | Medium | Anonymous Subscriber | `alert ip any any <> any any (msg:"Route10 nDPI security: anonymous subscriber"; ndpi-risk:NDPI_ANONYMOUS_SUBSCRIBER; sid:2920145; rev:1;)` |
| NDPI_UNIDIRECTIONAL_TRAFFIC | Low | Unidirectional Traffic | `alert ip any any <> any any (msg:"Route10 nDPI security: unidirectional traffic"; ndpi-risk:NDPI_UNIDIRECTIONAL_TRAFFIC; sid:2920146; rev:1;)` |
| NDPI_HTTP_OBSOLETE_SERVER | Medium | HTTP Obsolete Server | `alert ip any any <> any any (msg:"Route10 nDPI security: obsolete HTTP server"; ndpi-risk:NDPI_HTTP_OBSOLETE_SERVER; sid:2920147; rev:1;)` |
| NDPI_PERIODIC_FLOW | Low | Periodic Flow (Beacon) | `alert ip any any <> any any (msg:"Route10 nDPI security: periodic flow"; ndpi-risk:NDPI_PERIODIC_FLOW; sid:2920148; rev:1;)` |
| NDPI_MINOR_ISSUES | Low | Minor Issues | `alert ip any any <> any any (msg:"Route10 nDPI security: minor issues"; ndpi-risk:NDPI_MINOR_ISSUES; sid:2920149; rev:1;)` |
| NDPI_UNRESOLVED_HOSTNAME | Medium | Unresolved hostname | `alert ip any any <> any any (msg:"Route10 nDPI security: unresolved hostname"; ndpi-risk:NDPI_UNRESOLVED_HOSTNAME; sid:2920151; rev:1;)` |
| NDPI_TLS_ALPN_SNI_MISMATCH | Medium | ALPN/SNI Mismatch | `alert ip any any <> any any (msg:"Route10 nDPI security: ALPN/SNI mismatch"; ndpi-risk:NDPI_TLS_ALPN_SNI_MISMATCH; sid:2920152; rev:1;)` |
| NDPI_MALWARE_HOST_CONTACTED | Severe | Malware Host | `alert ip any any <> any any (msg:"Route10 nDPI security: malware host"; ndpi-risk:NDPI_MALWARE_HOST_CONTACTED; sid:2920153; rev:1;)` |
| NDPI_BINARY_DATA_TRANSFER | Medium | Binary Data Transfer | `alert ip any any <> any any (msg:"Route10 nDPI security: binary data transfer"; ndpi-risk:NDPI_BINARY_DATA_TRANSFER; sid:2920154; rev:1;)` |
| NDPI_PROBING_ATTEMPT | Medium | Probing Attempt | `alert ip any any <> any any (msg:"Route10 nDPI security: probing attempt"; ndpi-risk:NDPI_PROBING_ATTEMPT; sid:2920155; rev:1;)` |
| NDPI_OBFUSCATED_TRAFFIC | High | Obfuscated Traffic | `alert ip any any <> any any (msg:"Route10 nDPI security: obfuscated traffic"; ndpi-risk:NDPI_OBFUSCATED_TRAFFIC; sid:2920156; rev:1;)` |
