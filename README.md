# NV2ray

A black Liquid Glass-inspired macOS menu-bar client with VLESS, Hysteria2, custom DNS, rule-based routing, and a sing-box Packet Tunnel integration.

## Supported profiles

- VLESS: None, TLS, Reality
- VLESS transports: TCP, WebSocket, HTTP, XHTTP
- Hysteria2: TLS, TCP/UDP selection, bandwidth limits, port ranges, port hopping, Salamander or Gecko obfuscation

## Architecture

- `Sources/NV2ray/TunnelManager.swift` creates and controls a `NETunnelProviderManager`.
- The app sends the generated runtime configuration to the extension as `configContent`.
- `PacketTunnel/PacketTunnelProvider.swift` subclasses the official sing-box Apple `ExtensionProvider`.
- `RuntimeConfigBuilder.swift` generates a full configuration containing TUN, DNS, proxy outbounds, route rules, and the remote `category-ru` rule set.
- `project.yml` defines the macOS app and Packet Tunnel extension targets.

## Install the sing-box frameworks

The repository does not commit binary frameworks. Prepare an official `sing-box-for-apple` checkout containing `Libbox.xcframework`, then run:

```bash
chmod +x scripts/bootstrap-core.sh
./scripts/bootstrap-core.sh /path/to/sing-box-for-apple
```

The script copies `Libbox.xcframework`, builds `Library.framework`, and generates `NV2ray.xcodeproj` when XcodeGen is installed.

## Signing

Set your Apple Developer team in the generated Xcode project. The app and extension use:

- Network Extension entitlement: `packet-tunnel-provider`
- App Group: `group.io.github.junsl2.NV2ray`
- Extension bundle identifier: `io.github.junsl2.NV2ray.PacketTunnel`

A real connection requires valid Apple signing, user approval of the VPN configuration, and the two sing-box frameworks under `Vendor/`.
