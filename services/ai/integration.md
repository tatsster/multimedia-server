# AI Service Integration

Current AI/agent integration is centered on Hermes, OmniRoute, OpenViking, and Proxmox MCP Plus.

```text
Hermes CT108
  |-- model calls --> OmniRoute CT107 http://192.168.1.109:20128/v1
  |-- knowledge/memory --> OpenViking CT116 http://192.168.1.118:1933
  `-- Proxmox control/read tools --> Proxmox MCP Plus CT114 http://192.168.1.116:8000/mcp
```

## Services

| Service | Internal URL | Notes |
| --- | --- | --- |
| OmniRoute dashboard | `http://192.168.1.109:20128` | Private or Cloudflare Access only; admin UI and onboarding. |
| OmniRoute API | `http://192.168.1.109:20128/v1` | OpenAI-compatible endpoint for Hermes model calls. |
| OpenViking | `http://192.168.1.118:1933` | Knowledge base / long-term operational memory endpoint. |
| Proxmox MCP Plus | `http://192.168.1.116:8000/mcp` | MCP endpoint configured in Hermes as `proxmox_plus`. |

## Secret policy

Store provider keys, Proxmox tokens, Discord allowlists, and app credentials only in live Hermes/OmniRoute/OpenViking configuration or a password manager. Commit examples and placeholders only.

## Related docs

- [`agent/hermes/README.md`](../../agent/hermes/README.md)
- [`services/omniroute/README.md`](../omniroute/README.md)
- [`inventory/lxc-map.md`](../../inventory/lxc-map.md)
