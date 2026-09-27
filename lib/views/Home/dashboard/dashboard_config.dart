import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────
// IDs de widgets (KPIs y Gráficos)
// ─────────────────────────────────────────────
class WidgetId {
  // KPIs
  static const String kpiSalesMonth = 'kpi_sales_month';
  static const String kpiOrdersToday = 'kpi_orders_today';
  static const String kpiAvgTicket = 'kpi_avg_ticket';
  static const String kpiReturns = 'kpi_returns';

  // Gráficos
  static const String chartSalesYTD = 'chart_sales_ytd';
  static const String chartSalesCategory = 'chart_sales_category';
}

// ─────────────────────────────────────────────
// Tipo de widget
// ─────────────────────────────────────────────
enum DashboardWidgetType { kpi, chart }

// ─────────────────────────────────────────────
// Modelo de configuración de un widget
// ─────────────────────────────────────────────
class DashboardWidgetConfig {
  final String id;
  final DashboardWidgetType type;
  bool isVisible;
  int order;
  double chartHeight; // altura persistida para gráficos (px)
  double chartWidthFactor; // ancho persistido para gráficos (ej. 1.0 = 100%, 0.5 = 50%)
  String chartAlignment; // alineación: 'left', 'center', 'right'

  static const double defaultChartHeight = 420.0;
  static const double minChartHeight = 260.0;
  static const double maxChartHeight = 800.0;

  DashboardWidgetConfig({
    required this.id,
    required this.type,
    this.isVisible = true,
    this.order = 0,
    this.chartHeight = defaultChartHeight,
    this.chartWidthFactor = 1.0,
    this.chartAlignment = 'left',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'isVisible': isVisible,
        'order': order,
        'chartHeight': chartHeight,
        'chartWidthFactor': chartWidthFactor,
        'chartAlignment': chartAlignment,
      };

  factory DashboardWidgetConfig.fromJson(Map<String, dynamic> json) =>
      DashboardWidgetConfig(
        id: json['id'] as String,
        type: DashboardWidgetType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => DashboardWidgetType.kpi,
        ),
        isVisible: json['isVisible'] as bool? ?? true,
        order: json['order'] as int? ?? 0,
        chartHeight: (json['chartHeight'] as num?)?.toDouble() ?? defaultChartHeight,
        chartWidthFactor: (json['chartWidthFactor'] as num?)?.toDouble() ?? 1.0,
        chartAlignment: json['chartAlignment'] as String? ?? 'left',
      );
}

// ─────────────────────────────────────────────
// Controlador del dashboard (ChangeNotifier)
// ─────────────────────────────────────────────
class DashboardController extends ChangeNotifier {
  static const String _prefsKey = 'dashboard_config_v2';

  bool _editMode = false;
  bool get editMode => _editMode;

  List<DashboardWidgetConfig> _widgets = [];

  List<DashboardWidgetConfig> get kpiWidgets =>
      _widgets.where((w) => w.type == DashboardWidgetType.kpi).toList()
        ..sort((a, b) => a.order.compareTo(b.order));

  List<DashboardWidgetConfig> get chartWidgets =>
      _widgets.where((w) => w.type == DashboardWidgetType.chart).toList()
        ..sort((a, b) => a.order.compareTo(b.order));

  List<DashboardWidgetConfig> get visibleKpis =>
      kpiWidgets.where((w) => w.isVisible).toList();

  List<DashboardWidgetConfig> get visibleCharts =>
      chartWidgets.where((w) => w.isVisible).toList();

  List<DashboardWidgetConfig> get hiddenKpis =>
      kpiWidgets.where((w) => !w.isVisible).toList();

  List<DashboardWidgetConfig> get hiddenCharts =>
      chartWidgets.where((w) => !w.isVisible).toList();

  bool get hasHiddenWidgets => hiddenKpis.isNotEmpty || hiddenCharts.isNotEmpty;

  DashboardWidgetConfig? findById(String id) {
    try {
      return _widgets.firstWhere((w) => w.id == id);
    } catch (_) {
      return null;
    }
  }

  static List<DashboardWidgetConfig> _defaults() => [
        DashboardWidgetConfig(id: WidgetId.kpiSalesMonth, type: DashboardWidgetType.kpi, isVisible: true, order: 0),
        DashboardWidgetConfig(id: WidgetId.kpiOrdersToday, type: DashboardWidgetType.kpi, isVisible: true, order: 1),
        DashboardWidgetConfig(id: WidgetId.kpiAvgTicket, type: DashboardWidgetType.kpi, isVisible: true, order: 2),
        DashboardWidgetConfig(id: WidgetId.kpiReturns, type: DashboardWidgetType.kpi, isVisible: true, order: 3),
        DashboardWidgetConfig(id: WidgetId.chartSalesYTD, type: DashboardWidgetType.chart, isVisible: true, order: 0),
        DashboardWidgetConfig(id: WidgetId.chartSalesCategory, type: DashboardWidgetType.chart, isVisible: true, order: 1),
      ];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);

    if (raw != null) {
      try {
        final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
        final saved = decoded
            .map((e) => DashboardWidgetConfig.fromJson(e as Map<String, dynamic>))
            .toList();

        final savedIds = saved.map((s) => s.id).toSet();
        final defaults = _defaults();
        final newWidgets = defaults.where((d) => !savedIds.contains(d.id)).toList();

        for (var nw in newWidgets) {
          final maxOrder = saved
              .where((s) => s.type == nw.type)
              .map((s) => s.order)
              .fold<int>(-1, (prev, o) => o > prev ? o : prev);
          nw.order = maxOrder + 1;
        }

        _widgets = [...saved, ...newWidgets];
      } catch (_) {
        _widgets = _defaults();
      }
    } else {
      _widgets = _defaults();
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_widgets.map((w) => w.toJson()).toList());
    await prefs.setString(_prefsKey, encoded);
  }

  void toggleEditMode() {
    _editMode = !_editMode;
    notifyListeners();
  }

  void setEditMode(bool value) {
    if (_editMode == value) return;
    _editMode = value;
    notifyListeners();
  }

  void hideWidget(String id) {
    final w = findById(id);
    if (w == null) return;
    w.isVisible = false;
    notifyListeners();
    _save();
  }

  void showWidget(String id) {
    final w = findById(id);
    if (w == null) return;
    w.isVisible = true;
    notifyListeners();
    _save();
  }

  /// Actualiza la altura de un gráfico y persiste (sin notifyListeners para
  /// no re-renderizar el árbol completo durante el drag — el widget lo gestiona
  /// localmente y solo llama aquí al soltar).
  void setChartHeight(String id, double height) {
    final w = findById(id);
    if (w == null) return;
    w.chartHeight = height.clamp(
      DashboardWidgetConfig.minChartHeight,
      DashboardWidgetConfig.maxChartHeight,
    );
    _save();
  }

  void setChartWidth(String id, double widthFactor) {
    final w = findById(id);
    if (w == null) return;
    w.chartWidthFactor = widthFactor.clamp(0.2, 1.0);
    notifyListeners();
    _save();
  }

  void setChartAlignment(String id, String alignment) {
    final w = findById(id);
    if (w == null) return;
    w.chartAlignment = alignment;
    notifyListeners();
    _save();
  }

  void reorderKpis(int oldIndex, int newIndex) {
    final list = visibleKpis;
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    for (int i = 0; i < list.length; i++) {
      list[i].order = i;
    }
    notifyListeners();
    _save();
  }

  void reorderCharts(int oldIndex, int newIndex) {
    final list = visibleCharts;
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    for (int i = 0; i < list.length; i++) {
      list[i].order = i;
    }
    notifyListeners();
    _save();
  }

  void resetToDefaults() {
    _widgets = _defaults();
    notifyListeners();
    _save();
  }
}
