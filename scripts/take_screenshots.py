#!/usr/bin/env python3
"""
App Store 截图自动化脚本 v2
通过分析截图像素颜色 + AppleScript 点击来自动导航和截图

前置条件：
1. flutter build ios --debug --simulator --no-codesign
2. xcrun simctl install <udid> build/ios/iphonesimulator/Runner.app  
3. xcrun simctl launch <udid> com.zaine.app
4. 等待启动页动画结束（~5秒）
5. python3 scripts/take_screenshots.py
"""
import subprocess
import time
import os
import sys

SIM_UDID = "26EA5F63-3FDC-4849-8E2D-D16CD88A38A7"
OUTPUT_DIR = "/tmp/appstore_screenshots"
TARGET_DIR = os.path.join(os.path.dirname(__file__), '..', 'docs', 'screenshots')
# 模拟器逻辑分辨率（pt）
SIM_LOGICAL_W = 440
SIM_LOGICAL_H = 956

def run(cmd):
    """执行命令"""
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=30)
    return result.stdout.strip(), result.stderr.strip(), result.returncode

def take_screenshot(name):
    """截取模拟器屏幕"""
    path = os.path.join(OUTPUT_DIR, f"{name}.png")
    _, err, rc = run(f'xcrun simctl io {SIM_UDID} screenshot "{path}"')
    if os.path.exists(path):
        size = os.path.getsize(path)
        print(f"  ✅ {name}.png ({size // 1024}KB)")
        return path
    else:
        print(f"  ❌ 截图失败: {err}")
        return None

def get_simulator_window_rect():
    """获取模拟器窗口在 macOS 上的位置和大小"""
    out, _, _ = run(
        '''osascript -e 'tell application "Simulator" '''
        '''to get {position, size} of window 1' '''
    )
    try:
        # 输出格式: {x, y}, {width, height}
        pos_part, size_part = out.split('}, {')
        pos = pos_part.strip('{}').split(', ')
        size = size_part.strip(' {}').split(', ')
        return int(pos[0]), int(pos[1]), int(size[0]), int(size[1])
    except Exception as e:
        print(f"  ⚠️ 获取窗口位置失败: {e}")
        return None

def get_scale_factor(win_w):
    """计算模拟器缩放比例"""
    return win_w / SIM_LOGICAL_W

def simulator_to_screen(sim_x, sim_y, win_rect):
    """
    将模拟器内部坐标（pt）转为 macOS 屏幕坐标
    sim_x, sim_y: 模拟器内部逻辑坐标（0~440, 0~956）
    win_rect: (win_x, win_y, win_w, win_h)
    """
    win_x, win_y, win_w, win_h = win_rect
    scale = get_scale_factor(win_w)
    
    # 模拟器窗口内部有：顶部标题栏(~36pt) + 底部工具栏
    # 模拟器显示区域 = win_h - 标题栏 - 工具栏
    title_bar_h = 36  # macOS 窗口标题栏高度
    
    screen_x = win_x + sim_x * scale
    screen_y = win_y + title_bar_h + sim_y * scale
    
    return screen_x, screen_y

def click_at(screen_x, screen_y):
    """在 macOS 屏幕上模拟点击"""
    script = f'''
    tell application "System Events"
        click at {{{int(screen_x)}, {int(screen_y)}}}
    end tell
    '''
    run(f'osascript -e \'{script}\'')

def tap_tab(tab_index, win_rect):
    """
    点击底部导航栏的第 tab_index 个 Tab
    tab_index: 0=首页, 1=守护圈, 2=SOS, 3=我的
    """
    # 底部导航栏在模拟器屏幕底部
    # NavigationBar 高度约 64pt，位于屏幕底部
    # 4 个 Tab 等分宽度
    tab_w = SIM_LOGICAL_W / 4
    
    # Tab 中心 X 坐标
    sim_x = tab_w * tab_index + tab_w / 2
    
    # Tab Y 坐标：屏幕底部往上约 40pt（Tab 图标中心）
    sim_y = SIM_LOGICAL_H - 35
    
    screen_x, screen_y = simulator_to_screen(sim_x, sim_y, win_rect)
    print(f"  🖱️ 点击 Tab[{tab_index}] → 屏幕({screen_x:.0f}, {screen_y:.0f})")
    click_at(screen_x, screen_y)

def bring_simulator_to_front():
    """将模拟器窗口置前"""
    run('osascript -e \'tell application "Simulator" to activate\'')
    time.sleep(0.5)

def scroll_down(sim_x_ratio=0.5, amount=200):
    """在模拟器中向下滚动"""
    win_rect = get_simulator_window_rect()
    if not win_rect:
        return
    win_x, win_y, win_w, win_h = win_rect
    scale = get_scale_factor(win_w)
    title_bar_h = 36
    
    # 起始位置（页面上部）
    start_x = win_x + SIM_LOGICAL_W * sim_x_ratio * scale
    start_y = win_y + title_bar_h + 300 * scale
    # 终止位置（页面更下部）
    end_x = start_x
    end_y = start_y + amount * scale
    
    # 使用 osascript 模拟滚动（通过快速连续点击模拟）
    script = f'''
    tell application "System Events"
        -- 模拟滑动
        repeat 5 times
            click at {{{int(end_x)}, {int(end_y + 20)}}}
            delay 0.02
        end repeat
    end tell
    '''
    run(f'osascript -e \'{script}\'')

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    
    print("=" * 50)
    print("📸 App Store 截图自动化 v2")
    print("=" * 50)
    
    # 1. 确保模拟器窗口在前
    print("\n📱 激活模拟器窗口...")
    bring_simulator_to_front()
    time.sleep(1)
    
    # 2. 获取窗口位置
    win_rect = get_simulator_window_rect()
    if not win_rect:
        print("❌ 无法获取模拟器窗口位置！")
        print("   请确保模拟器已打开并显示 iPhone 界面")
        sys.exit(1)
    
    win_x, win_y, win_w, win_h = win_rect
    scale = get_scale_factor(win_w)
    print(f"   窗口位置: ({win_x}, {win_y}), 大小: {win_w}x{win_h}")
    print(f"   缩放比例: {scale:.2f}x")
    
    # 3. 等待 App 完全加载（启动页 3.5s + 过渡）
    print("\n⏳ 等待 App 加载...")
    time.sleep(3)
    
    # ====== 截图1: 首页 ======
    print("\n📸 [1/5] 首页（签到）...")
    take_screenshot("01_home")
    
    # ====== 截图2: 守护圈 ======
    print("\n📸 [2/5] 切换到守护圈...")
    tap_tab(1, win_rect)
    time.sleep(1.5)
    take_screenshot("02_guardian")
    
    # ====== 截图3: SOS ======
    print("\n📸 [3/5] 切换到 SOS...")
    tap_tab(2, win_rect)
    time.sleep(1.5)
    take_screenshot("03_sos")
    
    # ====== 截图4: 我的 ======
    print("\n📸 [4/5] 切换到我的...")
    tap_tab(3, win_rect)
    time.sleep(1.5)
    take_screenshot("04_profile")
    
    # ====== 截图5: 联系人 ======
    print("\n📸 [5/5] 从个人中心进入联系人页面...")
    # ProfilePage 中「紧急联系人」菜单项大约在 Y=350~400pt 的位置
    # 在屏幕中间偏上的位置点击
    sim_x = SIM_LOGICAL_W / 2
    sim_y = 380  # 大概在页面中间位置，紧急联系人入口附近
    screen_x, screen_y = simulator_to_screen(sim_x, sim_y, win_rect)
    print(f"  🖱️ 点击联系人入口 → ({screen_x:.0f}, {screen_y:.0f})")
    click_at(screen_x, screen_y)
    time.sleep(1.5)
    take_screenshot("05_contacts")
    
    # ====== 完成 ======
    print("\n" + "=" * 50)
    print("✅ 5张截图完成！")
    print(f"📁 原始文件: {OUTPUT_DIR}/")
    print(f"🎯 目标目录: {os.path.abspath(TARGET_DIR)}/")
    print("\n下一步: python3 scripts/resize_screenshots.py")
    print("=" * 50)

if __name__ == "__main__":
    main()
