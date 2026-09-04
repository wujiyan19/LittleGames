/**
 * 索引区间工具
 *
 * 由来：ArkTS 的 ForEach 不支持数字范围，于是各游戏页到处手写
 * `idx9: number[] = [0,1,2,3,4,5,6,7,8]` 这类数组（共 11 处，见报告 P1-5）。
 * 手写既啰嗦又容易与棋盘常量不一致——改了行数却忘了改数组就会越界。
 *
 * 统一改用 range(n) 生成，源头保证与 ROWS / COLS / SIZE 等常量对齐。
 */
export function range(n: number): number[] {
  const arr: number[] = [];
  for (let i = 0; i < n; i++) {
    arr.push(i);
  }
  return arr;
}
