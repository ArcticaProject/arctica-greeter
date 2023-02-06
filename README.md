# Arctica Greeter

## Configuration

- The default configuration is stored in dconf under the schema org.ArcticaProject.arctica-greeter.
- Distributions should set their own defaults using a GLib override.

# Features

- Arctica Greeter is cross-distribution and should work pretty much anywhere.
- Arctica Greeter uses Ayatana Indicators for the tray icons, so make sure they are available in your distribution, as well.
- This greeter supports HiDPI.
- Sessions are validated. If a default/chosen session isn't present on the system, the greeter scans for known sessions in /usr/share/xsessions and replaces the invalid session choice with a valid session.
- You can take a screenshot by pressing PrintScrn. The screenshot is saved in /var/lib/lightdm/Screenshot.png.

# Credits

- Arctica Greeter started as a fork of Unity Greeter 16.04.2, a greeter developed for Ubuntu by Canonical. Furtheron, various improvements are take from Slick Greeter, the LinuxMint fork of Unity Greeter.
