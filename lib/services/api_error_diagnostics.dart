class ApiErrorDiagnostics {
  const ApiErrorDiagnostics._();

  static String describeHttpFailure(
    int statusCode,
    String detail, {
    bool modelList = false,
  }) {
    final suffix = _detailSuffix(detail);
    if (modelList && statusCode == 404) {
      return '模型列表接口不存在（404）。这不代表聊天接口不可用；'
          '可以手动填写模型 ID，再用“测试连接”检查真正的聊天接口。$suffix';
    }

    return switch (statusCode) {
      400 =>
        '请求被接口拒绝（400）。通常是接口格式与平台不匹配，'
            '或该模型不支持当前请求参数。$suffix',
      401 =>
        'API Key 无效或未被识别（401）。请检查 Key 是否复制完整，'
            '以及是否属于当前平台。$suffix',
      403 =>
        'API Key 已识别，但没有访问权限（403）。请检查模型权限、'
            '账号区域或代理站权限。$suffix',
      404 =>
        '聊天接口或模型未找到（404）。请检查 Base URL、接口格式'
            '和模型 ID。$suffix',
      429 =>
        '请求被限流或额度不足（429）。请检查余额/配额，'
            '或稍后再试。$suffix',
      >= 500 && <= 599 =>
        '模型服务端暂时异常（$statusCode）。当前配置不一定有问题，'
            '可以稍后重试。$suffix',
      _ => '接口返回 $statusCode。$suffix',
    };
  }

  static String _detailSuffix(String detail) {
    final compact = detail.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (compact.isEmpty) return '';
    final visible = compact.length > 160
        ? '${compact.substring(0, 160)}…'
        : compact;
    return ' 服务端信息：$visible';
  }
}
