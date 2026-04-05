#!/usr/bin/env python3
"""
遍历指定文件夹下的所有 Dockerfile，依次执行：
1. docker build -f 文件 -t <tag>
2. docker push <tag>
3. docker rmi <tag>
路径与前缀通过命令行参数指定（见 --help）。
"""

import argparse
import os
import subprocess
import sys
from pathlib import Path


def get_dockerfile_paths(dir_path: str, recurse: bool) -> list[Path]:
    """收集目录下所有文件路径（视为 Dockerfile）。"""
    root = Path(dir_path).resolve()
    if not root.is_dir():
        raise FileNotFoundError(f"目录不存在: {root}")
    paths = []
    if recurse:
        for f in root.rglob("*"):
            if f.is_file():
                paths.append(f)
    else:
        for f in root.iterdir():
            if f.is_file():
                paths.append(f)
    return sorted(paths)


def run_cmd(cmd: list[str], cwd: Path | None = None) -> bool:
    """执行命令，返回是否成功。"""
    print(f"  $ {' '.join(cmd)}")
    ret = subprocess.run(cmd, cwd=cwd)
    if ret.returncode != 0:
        print(f"  失败 exit code: {ret.returncode}", file=sys.stderr)
        return False
    return True


def main(
    *,
    docker_data_root: str,
    dockerfile_dir: str,
    remote_image_prefix: str,
    recurse_subdirs: bool,
) -> None:
    # 使用指定数据根目录的 Docker（若为该目录单独起 daemon 并监听 socket）
    socket_path = Path(docker_data_root) / "docker.sock"
    if socket_path.exists():
        os.environ["DOCKER_HOST"] = f"unix://{socket_path}"

    dir_path = Path(dockerfile_dir).resolve()
    # 若为相对路径，则基于当前工作目录
    if not dir_path.is_absolute():
        dir_path = Path.cwd() / dir_path

    files = get_dockerfile_paths(str(dir_path), recurse_subdirs)
    if not files:
        print(f"未找到任何文件: {dir_path}")
        return

    print(f"共 {len(files)} 个文件，开始构建/推送/删除\n")

    for i, filepath in enumerate(files, 1):
        # tag = REMOTE_IMAGE_PREFIX:name（文件名去掉 _Dockerfile）
        name = filepath.name.removesuffix("_Dockerfile")
        image_tag = f"{remote_image_prefix}:{name}"

        print(f"[{i}/{len(files)}] {filepath.name} -> {image_tag}")

        # 构建上下文：Dockerfile 所在目录
        build_ctx = filepath.parent

        if not run_cmd(
            ["docker", "build", "-f", str(filepath), "-t", image_tag, "."],
            cwd=build_ctx,
        ):
            print(f"  跳过 push/rmi: 构建失败\n")
            continue

        if not run_cmd(["docker", "push", image_tag]):
            print(f"  跳过 rmi: 推送失败\n")
            continue

        run_cmd(["docker", "rmi", image_tag])
        print()

    print("全部完成。")


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="批量 build / push / rmi Dockerfile")
    ap.add_argument(
        "--docker-data-root",
        default="/mnt/storage/key4127_docker",
        help="Docker 数据根目录；若其下存在 docker.sock 则设置 DOCKER_HOST",
    )
    ap.add_argument(
        "--dockerfile-dir",
        default="./dockerfile/batch4_1/",
        help="存放 Dockerfile 的目录",
    )
    ap.add_argument(
        "--remote-image-prefix",
        default="key4127/refactor-dockerhub",
        help="远程镜像名前缀（不含 tag）",
    )
    ap.add_argument(
        "--recurse",
        action="store_true",
        help="递归遍历子目录中的文件",
    )
    args = ap.parse_args()
    main(
        docker_data_root=args.docker_data_root,
        dockerfile_dir=args.dockerfile_dir,
        remote_image_prefix=args.remote_image_prefix,
        recurse_subdirs=args.recurse,
    )
