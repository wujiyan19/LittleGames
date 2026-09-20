import { Context } from '@kit.AbilityKit';

/**
 * 将 Resource | string 解析为 string。
 * Resource 类型通过 resourceManager.getStringSync() 解析；
 * string 类型直接返回。
 * context 为 undefined 时返回空字符串（不崩溃，但搜索/排序功能暂时失效）。
 */
export function resolveString(value: Resource | string, context: Context | undefined): string {
  if (typeof value === 'string') {
    return value;
  }
  if (context) {
    return context.resourceManager.getStringSync(value);
  }
  return '';
}

/**
 * 将带占位符的 Resource 模板解析并替换为最终字符串。
 * 模板中使用 %1$d、%2$s 等占位符，args 按顺序对应。
 */
export function resolveFormattedString(
  template: Resource,
  args: string[],
  context: Context | undefined
): string {
  if (!context) { return ''; }
  let result: string = context.resourceManager.getStringSync(template);
  for (let i = 0; i < args.length; i++) {
    const placeholder = '%' + (i + 1) + '$d';
    const placeholderStr = '%' + (i + 1) + '$s';
    result = result.replace(placeholder, args[i]);
    result = result.replace(placeholderStr, args[i]);
  }
  return result;
}