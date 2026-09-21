/**
 * 触感反馈工具 — 封装 vibrator API，开关关闭或设备不支持时静默跳过
 *
 * 使用前需在 module.json5 声明 ohos.permission.VIBRATE（system_grant）。
 * 开关状态由 GameDataManager.getSetting('hapticsEnabled', true) 控制。
 */
import { vibrator } from '@kit.SensorServiceKit';
import { GameDataManager } from '../model/GameData';
import { hilog } from '@kit.PerformanceAnalysisKit';

export class Haptics {
  /** 轻触反馈（10ms）— 方向键、翻牌、敲地鼠等高频操作 */
  static tap(): void {
    if (!GameDataManager.getSetting('hapticsEnabled', true)) { return; }
    try {
      vibrator.startVibration({ type: 'time', duration: 10 }, { usage: 'touch' });
    } catch (e) {
      // 设备不支持或权限缺失时静默跳过，不影响游戏流程
      hilog.debug(0x0000, 'LittleGames', 'Haptics.tap failed, device may not support vibration');
    }
  }

  /** 成功反馈（40ms）— 对局胜利、通关等里程碑事件 */
  static success(): void {
    if (!GameDataManager.getSetting('hapticsEnabled', true)) { return; }
    try {
      vibrator.startVibration({ type: 'time', duration: 40 }, { usage: 'touch' });
    } catch (e) {
      hilog.debug(0x0000, 'LittleGames', 'Haptics.success failed, device may not support vibration');
    }
  }
}