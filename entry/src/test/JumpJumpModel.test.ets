/**
 * 跳一跳平台生成与满蓄力落点回归测试。
 */
import { describe, it, expect } from '@ohos/hypium';
import { GameDifficulty } from '../main/ets/common/GameConstants';
import { JumpJumpRules, JumpPlatform } from '../main/ets/model/game/JumpJumpModel';

export default function jumpJumpModelTest() {
  describe('JumpJumpRules', () => {
    it('full_charge_reaches_next_platform_at_every_difficulty', 0, () => {
      const difficulties: GameDifficulty[] = [GameDifficulty.EASY, GameDifficulty.NORMAL, GameDifficulty.HARD];
      for (let i = 0; i < difficulties.length; i++) {
        const difficulty: GameDifficulty = difficulties[i];
        const current: JumpPlatform = new JumpPlatform(100, JumpJumpRules.configFor(difficulty).width);
        const target: JumpPlatform = JumpJumpRules.spawnNext(current, difficulty);
        const landingX: number = current.centerX + JumpJumpRules.jumpDistance(1, difficulty);
        expect(JumpJumpRules.judge(landingX, target).landed).assertTrue();
      }
    });
  });
}
