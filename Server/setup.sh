#!/bin/bash
# Server/setup.sh

echo "=== CCTV 서비스 설치 시작 ==="

# 1. 루트 권한 확인
if [ "$EUID" -ne 0 ]; then
  echo "오류: 이 스크립트는 root 권한(sudo)으로 실행해야 합니다."
  exit 1
fi

# 실제 사용자 이름 가져오기 (sudo로 실행했어도 원래 유저를 찾음)
REAL_USER=$SUDO_USER
if [ -z "$REAL_USER" ]; then
  echo "오류: sudo를 통해 실행해 주세요."
  exit 1
fi

# 2. 작업 디렉토리 설정 (절대 경로 확보)
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_DIR=$(dirname "$SCRIPT_DIR") # 상위 폴더

SCRIPT_PATH="$SCRIPT_DIR/collect_cctv.py"
SERVICE_SOURCE="$SCRIPT_DIR/rpi-cctv-server.service"
SERVICE_DEST="/etc/systemd/system/rpi-cctv-server.service"
TIMER_SOURCE="$SCRIPT_DIR/rpi-cctv-server.timer"
TIMER_DEST="/etc/systemd/system/rpi-cctv-server.timer"

VENV_DIR="$SCRIPT_DIR/.venv"
VENV_PYTHON="$VENV_DIR/bin/python3"

echo "[Info] 사용자: $REAL_USER"
echo "[Info] venv 설치 경로: $VENV_DIR"

# 3. Python 가상환경 생성 (실제 사용자 권한으로 실행)
sudo -u $REAL_USER bash <<EOF
    cd "$SCRIPT_DIR"
    if [ ! -d ".venv" ]; then
        echo "Creating Python virtual environment..."
        python3 -m venv .venv
    fi
    
    # 가상환경 활성화 및 패키지 설치
    source .venv/bin/activate
    
    # 패키지 설치
    if [ -f "requirements.txt" ]; then
        pip install -r requirements.txt
    else
        echo "Warning: requirements.txt not found!"
    fi

    # 설정 파일 복사
    if [ ! -f "config.yaml" ] && [ -f "config.sample.yaml" ]; then
        cp config.sample.yaml config.yaml
        echo "Created config.yaml from sample."
    fi
EOF

# 4. systemd 서비스 파일 수정 및 등록
echo "[Info] 서비스 등록 중..."

# 서비스 파일 복사 및 경로 수정
sed "s|ExecStart=.*|ExecStart=$VENV_PYTHON $SCRIPT_PATH|; s|User=.*|User=$REAL_USER|" "$SERVICE_SOURCE" > "$SERVICE_DEST"

# 타이머 파일 복사
cp "$TIMER_SOURCE" "$TIMER_DEST"

# 5. 서비스 재로딩
systemctl daemon-reload

echo "[Info] 서비스 등록 완료"
echo ""
echo "서비스를 시작하려면:"
echo "  sudo systemctl start rpi-cctv-server.timer"
echo ""
echo "부팅 시 자동 시작하려면:"
echo "  sudo systemctl enable rpi-cctv-server.timer"
echo ""
echo "=== 설치 완료! ==="
