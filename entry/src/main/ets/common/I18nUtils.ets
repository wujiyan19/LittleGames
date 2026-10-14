import { Context } from '@kit.AbilityKit';

/**
 * 将 Resource | string 解析为 string。
 * Resource 类型通过资源 ID 和格式参数解析，避免已废弃的 Resource 重载；
 * string 类型直接返回。
 * context 为 undefined 时返回空字符串（不崩溃，但搜索/排序功能暂时失效）。
 */
export function resolveString(value: Resource | string, context: Context | undefined): string {
  if (typeof value === 'string') {
    return value;
  }
  if (context) {
    const args: Array<string | number> = [];
    if (value.params) {
      for (let i: number = 0; i < value.params.length; i++) {
        const param: string | number = value.params[i] as string | number;
        if (typeof param === 'string' || typeof param === 'number') { args.push(param); }
      }
    }
    try {
      return context.resourceManager.getStringSync(value.id, ...args);
    } catch (e) {
      return '';
    }
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
  let result: string = resolveString(template, context);
  for (let i = 0; i < args.length; i++) {
    const placeholder = '%' + (i + 1) + '$d';
    const placeholderStr = '%' + (i + 1) + '$s';
    result = result.replace(placeholder, args[i]);
    result = result.replace(placeholderStr, args[i]);
  }
  return result;
}
