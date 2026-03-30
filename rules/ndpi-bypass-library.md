# nDPI Bypass Rule Library

This file contains a ready-to-copy bypass rule for every protocol supported by the current version of `ndpi.so` plugin.

## Instructions

1. **Copy** the rule line you want.
2. **Paste** it into your `rules/route10-ndpi-bypass.rules` file.
3. **Apply** the changes by running:

   ```bash
   /bin/ash runner.sh apply
   ```

## Supported Protocols

| Protocol | Suricata Rule |
| :--- | :--- |
| 1kxun | `pass ip any any <> any any (msg:"Route10 nDPI bypass 1kxun"; ndpi-protocol:1kxun; sid:2910001; rev:1;)` |
| AFP | `pass ip any any <> any any (msg:"Route10 nDPI bypass AFP"; ndpi-protocol:AFP; sid:2910002; rev:1;)` |
| AH | `pass ip any any <> any any (msg:"Route10 nDPI bypass AH"; ndpi-protocol:AH; sid:2910003; rev:1;)` |
| AJP | `pass ip any any <> any any (msg:"Route10 nDPI bypass AJP"; ndpi-protocol:AJP; sid:2910004; rev:1;)` |
| Akamai | `pass ip any any <> any any (msg:"Route10 nDPI bypass Akamai"; ndpi-protocol:Akamai; sid:2910005; rev:1;)` |
| AliCloud | `pass ip any any <> any any (msg:"Route10 nDPI bypass AliCloud"; ndpi-protocol:AliCloud; sid:2910006; rev:1;)` |
| Alibaba | `pass ip any any <> any any (msg:"Route10 nDPI bypass Alibaba"; ndpi-protocol:Alibaba; sid:2910007; rev:1;)` |
| Amazon | `pass ip any any <> any any (msg:"Route10 nDPI bypass Amazon"; ndpi-protocol:Amazon; sid:2910008; rev:1;)` |
| AmazonAlexa | `pass ip any any <> any any (msg:"Route10 nDPI bypass AmazonAlexa"; ndpi-protocol:AmazonAlexa; sid:2910009; rev:1;)` |
| AmazonAWS | `pass ip any any <> any any (msg:"Route10 nDPI bypass AmazonAWS"; ndpi-protocol:AmazonAWS; sid:2910010; rev:1;)` |
| AmazonVideo | `pass ip any any <> any any (msg:"Route10 nDPI bypass AmazonVideo"; ndpi-protocol:AmazonVideo; sid:2910011; rev:1;)` |
| AMQP | `pass ip any any <> any any (msg:"Route10 nDPI bypass AMQP"; ndpi-protocol:AMQP; sid:2910012; rev:1;)` |
| AmongUs | `pass ip any any <> any any (msg:"Route10 nDPI bypass AmongUs"; ndpi-protocol:AmongUs; sid:2910013; rev:1;)` |
| AnonymousSubscriber | `pass ip any any <> any any (msg:"Route10 nDPI bypass AnonymousSubscriber"; ndpi-protocol:AnonymousSubscriber; sid:2910014; rev:1;)` |
| AnyDesk | `pass ip any any <> any any (msg:"Route10 nDPI bypass AnyDesk"; ndpi-protocol:AnyDesk; sid:2910015; rev:1;)` |
| Apple | `pass ip any any <> any any (msg:"Route10 nDPI bypass Apple"; ndpi-protocol:Apple; sid:2910016; rev:1;)` |
| AppleiCloud | `pass ip any any <> any any (msg:"Route10 nDPI bypass AppleiCloud"; ndpi-protocol:AppleiCloud; sid:2910017; rev:1;)` |
| AppleiTunes | `pass ip any any <> any any (msg:"Route10 nDPI bypass AppleiTunes"; ndpi-protocol:AppleiTunes; sid:2910018; rev:1;)` |
| ApplePush | `pass ip any any <> any any (msg:"Route10 nDPI bypass ApplePush"; ndpi-protocol:ApplePush; sid:2910019; rev:1;)` |
| AppleSiri | `pass ip any any <> any any (msg:"Route10 nDPI bypass AppleSiri"; ndpi-protocol:AppleSiri; sid:2910020; rev:1;)` |
| AppleStore | `pass ip any any <> any any (msg:"Route10 nDPI bypass AppleStore"; ndpi-protocol:AppleStore; sid:2910021; rev:1;)` |
| AppleTVPlus | `pass ip any any <> any any (msg:"Route10 nDPI bypass AppleTVPlus"; ndpi-protocol:AppleTVPlus; sid:2910022; rev:1;)` |
| AVAST | `pass ip any any <> any any (msg:"Route10 nDPI bypass AVAST"; ndpi-protocol:AVAST; sid:2910023; rev:1;)` |
| AWS_API_Gateway | `pass ip any any <> any any (msg:"Route10 nDPI bypass AWS_API_Gateway"; ndpi-protocol:AWS_API_Gateway; sid:2910024; rev:1;)` |
| AWS_Cloudfront | `pass ip any any <> any any (msg:"Route10 nDPI bypass AWS_Cloudfront"; ndpi-protocol:AWS_Cloudfront; sid:2910025; rev:1;)` |
| AWS_Cognito | `pass ip any any <> any any (msg:"Route10 nDPI bypass AWS_Cognito"; ndpi-protocol:AWS_Cognito; sid:2910026; rev:1;)` |
| AWS_DynamoDB | `pass ip any any <> any any (msg:"Route10 nDPI bypass AWS_DynamoDB"; ndpi-protocol:AWS_DynamoDB; sid:2910027; rev:1;)` |
| AWS_EC2 | `pass ip any any <> any any (msg:"Route10 nDPI bypass AWS_EC2"; ndpi-protocol:AWS_EC2; sid:2910028; rev:1;)` |
| AWS_EMR | `pass ip any any <> any any (msg:"Route10 nDPI bypass AWS_EMR"; ndpi-protocol:AWS_EMR; sid:2910029; rev:1;)` |
| AWS_Kinesis | `pass ip any any <> any any (msg:"Route10 nDPI bypass AWS_Kinesis"; ndpi-protocol:AWS_Kinesis; sid:2910030; rev:1;)` |
| AWS_S3 | `pass ip any any <> any any (msg:"Route10 nDPI bypass AWS_S3"; ndpi-protocol:AWS_S3; sid:2910031; rev:1;)` |
| Azure | `pass ip any any <> any any (msg:"Route10 nDPI bypass Azure"; ndpi-protocol:Azure; sid:2910032; rev:1;)` |
| Badoo | `pass ip any any <> any any (msg:"Route10 nDPI bypass Badoo"; ndpi-protocol:Badoo; sid:2910033; rev:1;)` |
| BGP | `pass ip any any <> any any (msg:"Route10 nDPI bypass BGP"; ndpi-protocol:BGP; sid:2910034; rev:1;)` |
| BitTorrent | `pass ip any any <> any any (msg:"Route10 nDPI bypass BitTorrent"; ndpi-protocol:BitTorrent; sid:2910035; rev:1;)` |
| Blizzard | `pass ip any any <> any any (msg:"Route10 nDPI bypass Blizzard"; ndpi-protocol:Blizzard; sid:2910036; rev:1;)` |
| Cloudflare | `pass ip any any <> any any (msg:"Route10 nDPI bypass Cloudflare"; ndpi-protocol:Cloudflare; sid:2910037; rev:1;)` |
| CloudflareWarp | `pass ip any any <> any any (msg:"Route10 nDPI bypass CloudflareWarp"; ndpi-protocol:CloudflareWarp; sid:2910038; rev:1;)` |
| CoD_Mobile | `pass ip any any <> any any (msg:"Route10 nDPI bypass CoD_Mobile"; ndpi-protocol:CoD_Mobile; sid:2910039; rev:1;)` |
| Deezer | `pass ip any any <> any any (msg:"Route10 nDPI bypass Deezer"; ndpi-protocol:Deezer; sid:2910040; rev:1;)` |
| DHCP | `pass ip any any <> any any (msg:"Route10 nDPI bypass DHCP"; ndpi-protocol:DHCP; sid:2910041; rev:1;)` |
| Discord | `pass ip any any <> any any (msg:"Route10 nDPI bypass Discord"; ndpi-protocol:Discord; sid:2910042; rev:1;)` |
| DisneyPlus | `pass ip any any <> any any (msg:"Route10 nDPI bypass DisneyPlus"; ndpi-protocol:DisneyPlus; sid:2910043; rev:1;)` |
| Dropbox | `pass ip any any <> any any (msg:"Route10 nDPI bypass Dropbox"; ndpi-protocol:Dropbox; sid:2910044; rev:1;)` |
| eBay | `pass ip any any <> any any (msg:"Route10 nDPI bypass eBay"; ndpi-protocol:eBay; sid:2910045; rev:1;)` |
| EpicGames | `pass ip any any <> any any (msg:"Route10 nDPI bypass EpicGames"; ndpi-protocol:EpicGames; sid:2910046; rev:1;)` |
| ESP | `pass ip any any <> any any (msg:"Route10 nDPI bypass ESP"; ndpi-protocol:ESP; sid:2910047; rev:1;)` |
| Facebook | `pass ip any any <> any any (msg:"Route10 nDPI bypass Facebook"; ndpi-protocol:Facebook; sid:2910048; rev:1;)` |
| FacebookMessenger | `pass ip any any <> any any (msg:"Route10 nDPI bypass FacebookMessenger"; ndpi-protocol:FacebookMessenger; sid:2910049; rev:1;)` |
| FacebookVoip | `pass ip any any <> any any (msg:"Route10 nDPI bypass FacebookVoip"; ndpi-protocol:FacebookVoip; sid:2910050; rev:1;)` |
| FastCGI | `pass ip any any <> any any (msg:"Route10 nDPI bypass FastCGI"; ndpi-protocol:FastCGI; sid:2910051; rev:1;)` |
| FTP_CONTROL | `pass ip any any <> any any (msg:"Route10 nDPI bypass FTP_CONTROL"; ndpi-protocol:FTP_CONTROL; sid:2910052; rev:1;)` |
| FTP_DATA | `pass ip any any <> any any (msg:"Route10 nDPI bypass FTP_DATA"; ndpi-protocol:FTP_DATA; sid:2910053; rev:1;)` |
| GenshinImpact | `pass ip any any <> any any (msg:"Route10 nDPI bypass GenshinImpact"; ndpi-protocol:GenshinImpact; sid:2910054; rev:1;)` |
| Github | `pass ip any any <> any any (msg:"Route10 nDPI bypass Github"; ndpi-protocol:Github; sid:2910055; rev:1;)` |
| GitLab | `pass ip any any <> any any (msg:"Route10 nDPI bypass GitLab"; ndpi-protocol:GitLab; sid:2910056; rev:1;)` |
| GMail | `pass ip any any <> any any (msg:"Route10 nDPI bypass GMail"; ndpi-protocol:GMail; sid:2910057; rev:1;)` |
| Google | `pass ip any any <> any any (msg:"Route10 nDPI bypass Google"; ndpi-protocol:Google; sid:2910058; rev:1;)` |
| GoogleClassroom | `pass ip any any <> any any (msg:"Route10 nDPI bypass GoogleClassroom"; ndpi-protocol:GoogleClassroom; sid:2910059; rev:1;)` |
| GoogleCloud | `pass ip any any <> any any (msg:"Route10 nDPI bypass GoogleCloud"; ndpi-protocol:GoogleCloud; sid:2910060; rev:1;)` |
| GoogleDocs | `pass ip any any <> any any (msg:"Route10 nDPI bypass GoogleDocs"; ndpi-protocol:GoogleDocs; sid:2910061; rev:1;)` |
| GoogleDrive | `pass ip any any <> any any (msg:"Route10 nDPI bypass GoogleDrive"; ndpi-protocol:GoogleDrive; sid:2910062; rev:1;)` |
| GoogleMaps | `pass ip any any <> any any (msg:"Route10 nDPI bypass GoogleMaps"; ndpi-protocol:GoogleMaps; sid:2910063; rev:1;)` |
| GoogleMeet | `pass ip any any <> any any (msg:"Route10 nDPI bypass GoogleMeet"; ndpi-protocol:GoogleMeet; sid:2910064; rev:1;)` |
| GoogleServices | `pass ip any any <> any any (msg:"Route10 nDPI bypass GoogleServices"; ndpi-protocol:GoogleServices; sid:2910065; rev:1;)` |
| GTP | `pass ip any any <> any any (msg:"Route10 nDPI bypass GTP"; ndpi-protocol:GTP; sid:2910066; rev:1;)` |
| Hamachi | `pass ip any any <> any any (msg:"Route10 nDPI bypass Hamachi"; ndpi-protocol:Hamachi; sid:2910067; rev:1;)` |
| HBO | `pass ip any any <> any any (msg:"Route10 nDPI bypass HBO"; ndpi-protocol:HBO; sid:2910068; rev:1;)` |
| HTTP | `pass ip any any <> any any (msg:"Route10 nDPI bypass HTTP"; ndpi-protocol:HTTP; sid:2910069; rev:1;)` |
| HTTP2 | `pass ip any any <> any any (msg:"Route10 nDPI bypass HTTP2"; ndpi-protocol:HTTP2; sid:2910070; rev:1;)` |
| Hulu | `pass ip any any <> any any (msg:"Route10 nDPI bypass Hulu"; ndpi-protocol:Hulu; sid:2910071; rev:1;)` |
| iCloudPrivateRelay | `pass ip any any <> any any (msg:"Route10 nDPI bypass iCloudPrivateRelay"; ndpi-protocol:iCloudPrivateRelay; sid:2910072; rev:1;)` |
| IMAP | `pass ip any any <> any any (msg:"Route10 nDPI bypass IMAP"; ndpi-protocol:IMAP; sid:2910073; rev:1;)` |
| IMAPS | `pass ip any any <> any any (msg:"Route10 nDPI bypass IMAPS"; ndpi-protocol:IMAPS; sid:2910074; rev:1;)` |
| IMO | `pass ip any any <> any any (msg:"Route10 nDPI bypass IMO"; ndpi-protocol:IMO; sid:2910075; rev:1;)` |
| Instagram | `pass ip any any <> any any (msg:"Route10 nDPI bypass Instagram"; ndpi-protocol:Instagram; sid:2910076; rev:1;)` |
| Kerberos | `pass ip any any <> any any (msg:"Route10 nDPI bypass Kerberos"; ndpi-protocol:Kerberos; sid:2910077; rev:1;)` |
| LDAP | `pass ip any any <> any any (msg:"Route10 nDPI bypass LDAP"; ndpi-protocol:LDAP; sid:2910078; rev:1;)` |
| LinkedIn | `pass ip any any <> any any (msg:"Route10 nDPI bypass LinkedIn"; ndpi-protocol:LinkedIn; sid:2910079; rev:1;)` |
| Microsoft | `pass ip any any <> any any (msg:"Route10 nDPI bypass Microsoft"; ndpi-protocol:Microsoft; sid:2910080; rev:1;)` |
| Microsoft365 | `pass ip any any <> any any (msg:"Route10 nDPI bypass Microsoft365"; ndpi-protocol:Microsoft365; sid:2910081; rev:1;)` |
| MQTT | `pass ip any any <> any any (msg:"Route10 nDPI bypass MQTT"; ndpi-protocol:MQTT; sid:2910082; rev:1;)` |
| MS_OneDrive | `pass ip any any <> any any (msg:"Route10 nDPI bypass MS_OneDrive"; ndpi-protocol:MS_OneDrive; sid:2910083; rev:1;)` |
| NetFlix | `pass ip any any <> any any (msg:"Route10 nDPI bypass NetFlix"; ndpi-protocol:NetFlix; sid:2910084; rev:1;)` |
| Nintendo | `pass ip any any <> any any (msg:"Route10 nDPI bypass Nintendo"; ndpi-protocol:Nintendo; sid:2910085; rev:1;)` |
| NTP | `pass ip any any <> any any (msg:"Route10 nDPI bypass NTP"; ndpi-protocol:NTP; sid:2910086; rev:1;)` |
| Ookla | `pass ip any any <> any any (msg:"Route10 nDPI bypass Ookla"; ndpi-protocol:Ookla; sid:2910087; rev:1;)` |
| OpenVPN | `pass ip any any <> any any (msg:"Route10 nDPI bypass OpenVPN"; ndpi-protocol:OpenVPN; sid:2910088; rev:1;)` |
| Oracle | `pass ip any any <> any any (msg:"Route10 nDPI bypass Oracle"; ndpi-protocol:Oracle; sid:2910089; rev:1;)` |
| Outlook | `pass ip any any <> any any (msg:"Route10 nDPI bypass Outlook"; ndpi-protocol:Outlook; sid:2910090; rev:1;)` |
| ParamountPlus | `pass ip any any <> any any (msg:"Route10 nDPI bypass ParamountPlus"; ndpi-protocol:ParamountPlus; sid:2910091; rev:1;)` |
| Playstation | `pass ip any any <> any any (msg:"Route10 nDPI bypass Playstation"; ndpi-protocol:Playstation; sid:2910092; rev:1;)` |
| PlayStore | `pass ip any any <> any any (msg:"Route10 nDPI bypass PlayStore"; ndpi-protocol:PlayStore; sid:2910093; rev:1;)` |
| QUIC | `pass ip any any <> any any (msg:"Route10 nDPI bypass QUIC"; ndpi-protocol:QUIC; sid:2910094; rev:1;)` |
| Radius | `pass ip any any <> any any (msg:"Route10 nDPI bypass Radius"; ndpi-protocol:Radius; sid:2910095; rev:1;)` |
| RDP | `pass ip any any <> any any (msg:"Route10 nDPI bypass RDP"; ndpi-protocol:RDP; sid:2910096; rev:1;)` |
| Reddit | `pass ip any any <> any any (msg:"Route10 nDPI bypass Reddit"; ndpi-protocol:Reddit; sid:2910097; rev:1;)` |
| RSYNC | `pass ip any any <> any any (msg:"Route10 nDPI bypass RSYNC"; ndpi-protocol:RSYNC; sid:2910098; rev:1;)` |
| RTCP | `pass ip any any <> any any (msg:"Route10 nDPI bypass RTCP"; ndpi-protocol:RTCP; sid:2910099; rev:1;)` |
| RTP | `pass ip any any <> any any (msg:"Route10 nDPI bypass RTP"; ndpi-protocol:RTP; sid:2910100; rev:1;)` |
| RTSP | `pass ip any any <> any any (msg:"Route10 nDPI bypass RTSP"; ndpi-protocol:RTSP; sid:2910101; rev:1;)` |
| Signal | `pass ip any any <> any any (msg:"Route10 nDPI bypass Signal"; ndpi-protocol:Signal; sid:2910102; rev:1;)` |
| SIP | `pass ip any any <> any any (msg:"Route10 nDPI bypass SIP"; ndpi-protocol:SIP; sid:2910103; rev:1;)` |
| Slack | `pass ip any any <> any any (msg:"Route10 nDPI bypass Slack"; ndpi-protocol:Slack; sid:2910104; rev:1;)` |
| SMBv23 | `pass ip any any <> any any (msg:"Route10 nDPI bypass SMBv23"; ndpi-protocol:SMBv23; sid:2910105; rev:1;)` |
| SMTP | `pass ip any any <> any any (msg:"Route10 nDPI bypass SMTP"; ndpi-protocol:SMTP; sid:2910106; rev:1;)` |
| SMTPS | `pass ip any any <> any any (msg:"Route10 nDPI bypass SMTPS"; ndpi-protocol:SMTPS; sid:2910107; rev:1;)` |
| SNMP | `pass ip any any <> any any (msg:"Route10 nDPI bypass SNMP"; ndpi-protocol:SNMP; sid:2910108; rev:1;)` |
| Spotify | `pass ip any any <> any any (msg:"Route10 nDPI bypass Spotify"; ndpi-protocol:Spotify; sid:2910109; rev:1;)` |
| SSH | `pass ip any any <> any any (msg:"Route10 nDPI bypass SSH"; ndpi-protocol:SSH; sid:2910110; rev:1;)` |
| Steam | `pass ip any any <> any any (msg:"Route10 nDPI bypass Steam"; ndpi-protocol:Steam; sid:2910111; rev:1;)` |
| SteamDatagramRelay | `pass ip any any <> any any (msg:"Route10 nDPI bypass SteamData"; ndpi-protocol:SteamDatagramRelay; sid:2910112; rev:1;)` |
| STUN | `pass ip any any <> any any (msg:"Route10 nDPI bypass STUN"; ndpi-protocol:STUN; sid:2910113; rev:1;)` |
| Teams | `pass ip any any <> any any (msg:"Route10 nDPI bypass Teams"; ndpi-protocol:Teams; sid:2910114; rev:1;)` |
| Telegram | `pass ip any any <> any any (msg:"Route10 nDPI bypass Telegram"; ndpi-protocol:Telegram; sid:2910115; rev:1;)` |
| Telnet | `pass ip any any <> any any (msg:"Route10 nDPI bypass Telnet"; ndpi-protocol:Telnet; sid:2910116; rev:1;)` |
| TikTok | `pass ip any any <> any any (msg:"Route10 nDPI bypass TikTok"; ndpi-protocol:TikTok; sid:2910117; rev:1;)` |
| TLS | `pass ip any any <> any any (msg:"Route10 nDPI bypass TLS"; ndpi-protocol:TLS; sid:2910118; rev:1;)` |
| Twitch | `pass ip any any <> any any (msg:"Route10 nDPI bypass Twitch"; ndpi-protocol:Twitch; sid:2910119; rev:1;)` |
| Twitter | `pass ip any any <> any any (msg:"Route10 nDPI bypass Twitter"; ndpi-protocol:Twitter; sid:2910120; rev:1;)` |
| Viber | `pass ip any any <> any any (msg:"Route10 nDPI bypass Viber"; ndpi-protocol:Viber; sid:2910121; rev:1;)` |
| Vimeo | `pass ip any any <> any any (msg:"Route10 nDPI bypass Vimeo"; ndpi-protocol:Vimeo; sid:2910122; rev:1;)` |
| WebSocket | `pass ip any any <> any any (msg:"Route10 nDPI bypass WebSocket"; ndpi-protocol:WebSocket; sid:2910123; rev:1;)` |
| WhatsApp | `pass ip any any <> any any (msg:"Route10 nDPI bypass WhatsApp"; ndpi-protocol:WhatsApp; sid:2910124; rev:1;)` |
| WhatsAppCall | `pass ip any any <> any any (msg:"Route10 nDPI bypass WhatsAppCall"; ndpi-protocol:WhatsAppCall; sid:2910125; rev:1;)` |
| WhatsAppFiles | `pass ip any any <> any any (msg:"Route10 nDPI bypass WhatsAppFiles"; ndpi-protocol:WhatsAppFiles; sid:2910126; rev:1;)` |
| WindowsUpdate | `pass ip any any <> any any (msg:"Route10 nDPI bypass WindowsUpdate"; ndpi-protocol:WindowsUpdate; sid:2910127; rev:1;)` |
| WireGuard | `pass ip any any <> any any (msg:"Route10 nDPI bypass WireGuard"; ndpi-protocol:WireGuard; sid:2910128; rev:1;)` |
| Xbox | `pass ip any any <> any any (msg:"Route10 nDPI bypass Xbox"; ndpi-protocol:Xbox; sid:2910129; rev:1;)` |
| YouTube | `pass ip any any <> any any (msg:"Route10 nDPI bypass YouTube"; ndpi-protocol:YouTube; sid:2910130; rev:1;)` |
| Zoom | `pass ip any any <> any any (msg:"Route10 nDPI bypass Zoom"; ndpi-protocol:Zoom; sid:2910131; rev:1;)` |
