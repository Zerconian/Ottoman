# Ottoman and Home Assistant

Ottoman's input daemon serves a small local HTTP API on port 18820 (the same one the phone remote uses).
No authentication: it is meant for the LAN only, like the phone page. `<box>` is the Ottoman box's address.

| Call | Effect |
|---|---|
| `POST http://<box>:18820/power?state=off` | display off (the box itself never sleeps) |
| `POST http://<box>:18820/power?state=on` | display on and back to the home screen |
| `POST http://<box>:18820/key?name=play` | play/pause (also: home, back, up, down, left, right, ok, menu, volup, voldown, mute, pointer) |
| `GET http://<box>:18820/status` | JSON: pointer mode, key names |

`configuration.yaml`:

```yaml
rest_command:
  ottoman_off:
    url: "http://<box>:18820/power?state=off"
    method: post
  ottoman_on:
    url: "http://<box>:18820/power?state=on"
    method: post
  ottoman_playpause:
    url: "http://<box>:18820/key?name=play"
    method: post

switch:
  - platform: template
    switches:
      ottoman_tv:
        friendly_name: "Ottoman"
        turn_on:
          service: rest_command.ottoman_on
        turn_off:
          service: rest_command.ottoman_off
```

Expose `switch.ottoman_tv` to Alexa, Google Assistant or HomeKit through Home Assistant's own bridges and
"turn off Ottoman" works from any of them. With HDMI-CEC (once the box has it) the TV's own off also puts
the box to standby, no integration needed.
