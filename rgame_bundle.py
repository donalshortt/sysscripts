"""Build and stage the Linux game, assets, and Cargo-provided runtime libraries."""

import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess


LFS_SIGNATURE = b"version https://git-lfs.github.com/spec/v1"


def build_bundle(project: Path, destination: Path) -> None:
    """Stage a playtest bundle in an empty directory owned by the caller."""
    project = project.resolve()
    destination = destination.resolve()
    environment = _build_environment()
    shutil.copytree(
        project / "assets", destination / "assets",
        ignore=shutil.ignore_patterns(".gitattributes"),
        copy_function=lambda source, target: _copy_asset(project, environment, source, target),
    )

    executable, cargo_library_dirs = _build(project, environment)
    rust_library_dir = _rust_library_dir(project)
    library_dirs = (executable.parent / "deps", *cargo_library_dirs, rust_library_dir)
    resolved_dirs = tuple(path.resolve() for path in dict.fromkeys(library_dirs))
    dependencies = _linked_libraries(executable, resolved_dirs)

    staged_executable = destination / executable.name
    _stage_elf(executable, staged_executable)

    staged_lib_dir = destination / "lib"
    staged_lib_dir.mkdir()
    bundled = {}
    for name, path in dependencies.items():
        if any(path.is_relative_to(directory) for directory in resolved_dirs):
            bundled[name] = staged_lib_dir / name
            _stage_elf(path, bundled[name])

    staged_dependencies = _linked_libraries(staged_executable, (staged_lib_dir,))
    for name, path in bundled.items():
        if staged_dependencies.get(name) != path:
            raise RuntimeError(f"Staged executable does not load {name} from its bundle")


def _stage_elf(source: Path, destination: Path) -> None:
    subprocess.run(["strip", "--strip-debug", "-o", destination, source], check=True)
    shutil.copystat(source, destination)


def _copy_asset(project: Path, environment: dict[str, str], source: str, destination: str) -> str:
    with open(source, "rb", buffering=0) as asset:
        if asset.read(len(LFS_SIGNATURE)) != LFS_SIGNATURE:
            return shutil.copy2(source, destination)
        asset.seek(0)
        smudge_environment = {**environment, "GIT_LFS_SKIP_SMUDGE": "0"}
        name = str(Path(source).relative_to(project))
        expected = next(
            (line.removeprefix(b"oid sha256:").strip() for line in asset if line.startswith(b"oid sha256:")),
            None,
        )
        asset.seek(0)
        with open(destination, "w+b") as target:
            result = subprocess.run(
                ["git", "lfs", "smudge", name], env=smudge_environment,
                cwd=project, stdin=asset, stdout=target,
            )
            target.seek(0)
            if result.returncode or hashlib.file_digest(target, "sha256").hexdigest().encode() != expected:
                raise RuntimeError(f"Could not materialize the Git LFS asset {name}.")
    shutil.copystat(source, destination)
    return destination


def _build_environment() -> dict[str, str]:
    environment = os.environ.copy()
    path = environment.get("PATH", os.defpath)
    user_bin = str(Path.home() / ".local" / "bin")
    if user_bin not in path.split(os.pathsep):
        path += os.pathsep + user_bin
    environment["PATH"] = path
    if shutil.which("cgame", path=path):
        # Match the normal handoff build, including Cargo's inherited configuration.
        return environment

    dependency_file = Path.home() / ".config" / "rgame" / "native-dependencies"
    if dependency_file.is_file():
        linker = shutil.which("ld.lld", path=path)
        lfs = shutil.which("git-lfs", path=path)
        pkg_config = subprocess.run(
            ["pkg-config", "--exists", "alsa", "xkbcommon", "wayland-client"], check=False,
        )
        cpp_library = subprocess.check_output(
            ["clang", "--print-file-name=libstdc++.so"], text=True,
        ).strip()
        if linker is None or lfs is None or pkg_config.returncode or not Path(cpp_library).is_absolute():
            prefix = Path(dependency_file.read_text().strip())
            environment["PATH"] = str(prefix / "usr" / "bin") + os.pathsep + environment["PATH"]
            libraries = prefix / "usr" / "lib" / "x86_64-linux-gnu"
            for key, directory in (("LIBRARY_PATH", libraries), ("PKG_CONFIG_PATH", libraries / "pkgconfig")):
                previous = environment.get(key)
                environment[key] = str(directory) + (os.pathsep + previous if previous else "")
    return environment


def _build(project: Path, environment: dict[str, str]) -> tuple[Path, list[Path]]:
    cargo = shutil.which("cgame", path=environment["PATH"]) or "cargo"
    result = subprocess.run(
        [cargo, "build", "--message-format=json-render-diagnostics"],
        cwd=project, env=environment, stdout=subprocess.PIPE, text=True,
    )
    if result.returncode:
        raise RuntimeError(f"Game build failed with exit status {result.returncode}")

    binary = environment.get("RGAME_BIN")
    executables = set()
    library_dirs = []
    for line in result.stdout.splitlines():
        if not line.startswith("{"):
            continue
        message = json.loads(line)
        if message.get("reason") != "compiler-artifact":
            continue
        target = message["target"]
        if (
            "bin" in target["kind"]
            and message.get("executable")
            and (not binary or target["name"] == binary)
        ):
            executables.add(project / message["executable"])
        for filename in message.get("filenames", []):
            path = project / filename
            if path.suffix == ".so":
                library_dirs.append(path.parent)
    if len(executables) > 1:
        if binary:
            raise RuntimeError("Cargo built multiple executables matching RGAME_BIN")
        raise RuntimeError("Cargo built multiple executables. Set RGAME_BIN to the game target name.")
    executable = next(iter(executables), None)
    if executable is None or not executable.is_file():
        if binary:
            raise RuntimeError("Cargo did not report a built executable for RGAME_BIN")
        raise RuntimeError("Cargo did not report a built game executable")
    return executable, library_dirs


def _rust_library_dir(project: Path) -> Path:
    rustc = os.environ.get("RUSTC") or os.environ.get("CARGO_BUILD_RUSTC") or "rustc"
    output = subprocess.check_output([rustc, "--print", "target-libdir"], cwd=project, text=True)
    directory = Path(output.strip())
    if not directory.is_absolute() or not directory.is_dir():
        raise RuntimeError(f"Rust reported an invalid target library directory: {output.strip()}")
    return directory


def _linked_libraries(executable: Path, library_dirs: tuple[Path, ...]) -> dict[str, Path]:
    environment = os.environ.copy()
    environment.pop("LD_PRELOAD", None)
    environment.pop("LD_AUDIT", None)
    environment["LC_ALL"] = "C"
    environment["LD_LIBRARY_PATH"] = os.pathsep.join(map(str, library_dirs))
    result = subprocess.run(["ldd", executable], env=environment, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True)
    if result.returncode:
        raise RuntimeError(f"Could not inspect {executable}: {result.stdout.strip()}")

    libraries = {}
    for line in result.stdout.splitlines():
        name, separator, value = line.strip().partition(" => ")
        if not separator:
            continue
        if value == "not found":
            raise RuntimeError(f"Missing runtime library {name} required by {executable}")
        path_text, address, _ = value.rpartition(" (0x")
        path = Path(path_text)
        if not address or not path.is_absolute():
            raise RuntimeError(f"Unexpected ldd output for {executable}: {line.strip()}")
        libraries[Path(name).name] = path.resolve(strict=True)
    return libraries
