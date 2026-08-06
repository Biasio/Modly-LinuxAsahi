# Modly-LinuxAsahi

<p align="center">
<img width=30% alt="image" src="https://github.com/user-attachments/assets/8346088f-4a4e-4a41-83dc-8d91b74d9c03" />
</p>

Containerized setup to run [Modly](https://github.com/lightningpixel/modly) on Asahi Linux, without installing its dependencies (Node, Python, Vulkan/Mesa drivers) directly on the host system.

## What it does

The project builds a Podman image based on Fedora with the Asahi stack graphics packages (Mesa, libglvnd, Vulkan drivers), clones and compiles Modly inside it, and launches it with access to the host's GPU and display server (X11 or Wayland).

## Requirements

- Podman
- Asahi Linux system (or otherwise with compatible DRI/Vulkan Mesa drivers)
- An active display server (X11 or Wayland) with `DISPLAY` or `WAYLAND_DISPLAY` exported

## Usage

```bash
./run.sh
```

On first run, the script compiles the image (`podman build`) if it is not already present, then starts the container mounting:

- the host's X11/Wayland socket, to display the application window;
- `/dev/dri`, for GPU access;
- a persistent volume (`modly_user_data`) for Modly user data linked to a shared directory (`~/.local/share/modly/shared-volume`) for file exchange with the host.

Eventual environment configuration (variables, keys, etc.) must be defined in an `env.conf` file in the project directory.

## Structure

| File | Role |
|---|---|
| `Dockerfile` | Multi-stage build: compiles Modly in a separate stage and produces a final image containing only the necessary runtime. |
| `entrypoint.sh` | Script executed at container startup: activates the Python virtualenv, configures Ozone/Wayland if detected, starts Modly (`npm run preview`). |
| `run.sh` | Host-side script: verifies requirements, prepares mounts and permissions, starts the container. |
| `env.conf` | Eventual environment configuration (variables, keys, etc.) should be defined here. |
## Notes

- The user inside the container is non-privileged (UID 1000, `video` group).
- The `xhost` permission granted for X11 access is automatically revoked upon script exit, even in case of errors.


# License

> This repo is heavily based on the work of [Modly](https://github.com/lightningpixel/modly) by [Lightning Pixel](https://github.com/lightningpixel)

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
