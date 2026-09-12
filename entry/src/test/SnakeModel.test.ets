/**
 * 贪吃蛇 Model 层单测
 *
 * 因为 Model（SnakeRules / RandomSource）零 ArkUI 依赖，这里可直接构造与断言。
 * 随机用 SeededRandom 保证确定性。
 */
import { describe, it, expect } from '@ohos/hypium';
import { Direction, Point, SeededRandom, SnakeRules } from '../main/ets/model/game/SnakeModel';

export default function snakeModelTest() {
  describe('SnakeRules', () => {
    const rules = new SnakeRules(20, 20);

    it('step_moves_head_one_cell', 0, () => {
      const snake: Point[] = [new Point(10, 10)];
      const out = rules.step(snake, Direction.RIGHT, new Point(-1, -1), 0);
      expect(out.dead).assertFalse();
      expect(out.ate).assertFalse();
      expect(out.snake.length).assertEqual(1);
      expect(out.snake[0].x).assertEqual(11);
      expect(out.snake[0].y).assertEqual(10);
    });

    it('step_into_wall_dies', 0, () => {
      const snake: Point[] = [new Point(0, 5)];
      const out = rules.step(snake, Direction.LEFT, new Point(-1, -1), 0);
      expect(out.dead).assertTrue();
    });

    it('step_into_vacating_tail_is_allowed', 0, () => {
      // 头 (5,5) 向下到 (5,6)，恰是尾格；未吃食物时尾会让位，不算碰撞
      const snake: Point[] = [new Point(5, 5), new Point(4, 5), new Point(4, 6), new Point(5, 6)];
      const out = rules.step(snake, Direction.DOWN, new Point(15, 15), 0);
      expect(out.dead).assertFalse();
    });

    it('step_into_body_dies', 0, () => {
      // 头向左进入 (4,5) —— 脖子，非尾格
      const snake: Point[] = [new Point(5, 5), new Point(4, 5), new Point(4, 6), new Point(5, 6)];
      const out = rules.step(snake, Direction.LEFT, new Point(15, 15), 0);
      expect(out.dead).assertTrue();
    });

    it('eat_food_grows_and_scores_ten', 0, () => {
      const snake: Point[] = [new Point(5, 5)];
      const out = rules.step(snake, Direction.RIGHT, new Point(6, 5), 0);
      expect(out.dead).assertFalse();
      expect(out.ate).assertTrue();
      expect(out.snake.length).assertEqual(2);
      expect(out.score).assertEqual(10);
    });

    it('spawn_food_returns_negative_when_board_full', 0, () => {
      // 2x1 棋盘被蛇占满 → 无处生成食物
      const tiny = new SnakeRules(2, 1);
      const full: Point[] = [new Point(0, 0), new Point(1, 0)];
      const food = tiny.spawnFood(full, new SeededRandom(1));
      expect(food.x).assertEqual(-1);
      expect(food.y).assertEqual(-1);
    });

    it('turn_allowed_blocks_reverse_and_same', 0, () => {
      expect(rules.turnAllowed(Direction.RIGHT, Direction.LEFT)).assertFalse();
      expect(rules.turnAllowed(Direction.RIGHT, Direction.RIGHT)).assertFalse();
      expect(rules.turnAllowed(Direction.RIGHT, Direction.UP)).assertTrue();
      expect(rules.turnAllowed(Direction.UP, Direction.LEFT)).assertTrue();
    });

    it('seeded_random_is_deterministic', 0, () => {
      const a = new SeededRandom(42);
      const b = new SeededRandom(42);
      expect(a.next()).assertEqual(b.next());
      expect(a.next()).assertEqual(b.next());
    });
  });
}
