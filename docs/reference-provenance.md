# Reference provenance

Desktop Pong Overlay is implemented from scratch as a native Swift/AppKit/SpriteKit/SwiftUI app.
The repositories below were used as reference material for MAR-7 only; no source files,
assets, shaders, icons, or branding from them are vendored or copied into this project.

| Reference | Upstream HEAD checked | Used for |
| --- | --- | --- |
| `https://github.com/dashersw/liquid-glass-js.git` | `78cb6ccb0b9987bb60a88b14ccbd13a9e6e8ab2a` | Liquid-glass controls, rim/specular/depth concepts, and live tuning vocabulary. |
| `https://github.com/mlitb/pong.git` | `293115e2f8985f7de51d0b74eabc1c7bf92620a1` | AI/gameplay feel reference only. |
| `https://github.com/MatthewTamYT/Pong.git` | `1eb2f77704918c6f2515cd2297c402ac997371c3` | Simple Pong mode/control reference only. |

The default Liquid Glass implementation remains object-local and does not sample the desktop
or request Screen Recording permission.
