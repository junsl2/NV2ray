# NV2ray

A black Liquid Glass-inspired macOS menu-bar client with VLESS, Hysteria2, custom DNS, rule-based routing, a kill switch, and a sing-box Packet Tunnel integration.

## Supported profiles

- VLESS: None, TLS, Reality
- VLESS transports: TCP, WebSocket, HTTP, XHTTP
- Hysteria2: TLS, TCP/UDP selection, bandwidth limits, port ranges, port hopping, Salamander or Gecko obfuscation

## Kill switch

The optional kill switch applies protection at both the macOS Network Extension and sing-box layers:

- Enables `includeAllNetworks` and route enforcement on the VPN protocol
- Enables an On Demand reconnect rule while protection is active
- Passes `includeAllNetworks` to the sing-box Apple extension
- Changes the TUN stack from `system` to `gvisor`
- Keeps local-network bypass disabled unless the user explicitly enables it
- Removes default `direct` outbound while protected mode is active
- Forces encrypted DNS, bootstrap DNS, and rule-set downloads through the proxy path
- Converts user `direct` routing rules to `proxy`, except private LAN CIDR rules when local-network access is explicitly allowed
- Applies `ipv4_only` DNS strategy when IPv6 answer blocking is enabled

Protected mode intentionally rejects unsafe combinations before connecting:

- `System DNS`
- `Direct` routing mode
- Insecure TLS verification
- Domain-based proxy server addresses
- Domain-based encrypted DNS endpoints

Use an IP address in the server field and an IP-based encrypted DNS endpoint such as `https://1.1.1.1/dns-query` when protected mode is enabled. Keep the SNI / server name field set for TLS verification.

An intentional Stop action disables On Demand before stopping the tunnel, so normal network access is restored. Changes made while connected require a reconnect.

## Secret handling

- VLESS UUID, Hysteria2 password, and obfuscation password are stored in macOS Keychain.
- Disk configuration is redacted before writing.
- Legacy plaintext values are migrated into Keychain on load.
- The generated runtime config preview is redacted by default. Use Reveal Full only for local debugging.

## Architecture

- `Sources/NV2ray/TunnelManager.swift` creates and controls a `NETunnelProviderManager`.
- The app sends the generated runtime configuration to the extension as `configContent`.
- `PacketTunnel/PacketTunnelProvider.swift` subclasses the official sing-box Apple `ExtensionProvider`.
- `RuntimeConfigBuilder.swift` generates a full configuration containing TUN, DNS, proxy outbounds, route rules, and the remote `category-ru` rule set.
- `RuntimeConfigPostProcessor.swift` applies final safety hardening such as DNS strategy.
- `project.yml` defines the macOS app and Packet Tunnel extension targets.

## Install the sing-box frameworks

The repository does not commit binary frameworks. Prepare an official `sing-box-for-apple` checkout at the tested revision, then run:

```bash
chmod +x scripts/bootstrap-core.sh
./scripts/bootstrap-core.sh /path/to/sing-box-for-apple
```

The script verifies the tested upstream commit, copies `Libbox.xcframework`, builds `Library.framework`, writes `Vendor/core-version.txt`, and generates `NV2ray.xcodeproj` when XcodeGen is installed.

To override the revision check for local experiments:

```bash
ALLOW_UNTESTED_CORE=1 ./scripts/bootstrap-core.sh /path/to/sing-box-for-apple
```

## Local signed build

After installing the frameworks and XcodeGen, run:

```bash
DEVELOPMENT_TEAM=YOURTEAMID scripts/build-signed.sh
```

This generates the Xcode project and builds the app plus Packet Tunnel extension with local signing settings.

## Signing

Set your Apple Developer team in the generated Xcode project. The app and extension use:

- Network Extension entitlement: `packet-tunnel-provider`
- App Group: `group.io.github.junsl2.NV2ray`
- Extension bundle identifier: `io.github.junsl2.NV2ray.PacketTunnel`

A real connection requires valid Apple signing, user approval of the VPN configuration, and the two sing-box frameworks under `Vendor/`.
