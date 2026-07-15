/// 功能开关配置 - v1.0 首版精简
///
/// 使用方式：FeatureFlags.enableXxx 控制功能显隐
/// 后续版本迭代只需将 false 改为 true 即可逐步开放新功能
class FeatureFlags {
  // ========== v1.0 首版开启（八大核心功能）==========

  /// 启动引导 & 登录注册
  static const bool enableOnboarding = true;

  /// 首页 + 每日签到
  static const bool enableCheckIn = true;

  /// 紧急求助 SOS（GPS + 一键拨打）
  static const bool enableSOS = true;

  /// 个人健康档案（基础档案信息）
  static const bool enableHealthProfile = true;

  /// 紧急联系人管理
  static const bool enableContacts = true;

  /// 守护圈
  static const bool enableGuardian = true;

  /// 守护卡裂变（Deep Link + 开包仪式）
  static const bool enableGuardianCard = true;

  /// 设置页
  static const bool enableSettings = true;

  /// IAP 订阅
  static const bool enableIAP = true;

  // ========== v1.0 首版隐藏（后续版本逐个开放）==========

  /// HealthKit / Apple Watch 健康数据同步（生命体征守护）
  static const bool enableHealthKit = true;

  /// 情绪感知引擎
  static const bool enableEmotion = false;

  /// AI 健康分析
  static const bool enableAIAnalysis = false;

  /// 虚拟精灵系统
  static const bool enableSpirit = false;

  /// 语音消息
  static const bool enableVoiceMessage = false;

  /// 社交互动
  static const bool enableSocial = false;

  /// 数据统计图表（热力图/趋势图等高级统计）
  static const bool enableStatistics = false;

  /// 经期预测
  static const bool enableMenstruation = true;

  /// 成就系统
  static const bool enableAchievements = false;

  /// 新手任务卡片
  static const bool enableNewbieTask = false;

  /// 营销展示页
  static const bool enablePromotionalShowcase = false;

  /// 开发者模式（Release 包自动屏蔽）
  static const bool enableDeveloperMode =
      !bool.fromEnvironment('dart.vm.product');

  // ========== 中国区首版隐藏（后续版本放开请将对应开关设为 true）==========
  // 说明：cn 区首版为规避 dead-man switch 审核风险，先隐藏以下三项；
  // 全球版(global) 不受影响。后续要在 cn 重新开放，仅需把对应开关改为 true。

  /// 定时平安确认 / 漏签（cn 首版隐藏）
  static const bool enableCheckInReminderCn = false;

  /// 地理围栏 / 安全区域（cn 首版隐藏）
  static const bool enableGeoFenceCn = false;

  /// 跌倒检测（cn 首版隐藏）
  static const bool enableFallDetectionCn = false;
}
