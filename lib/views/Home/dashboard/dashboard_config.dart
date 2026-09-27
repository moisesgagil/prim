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
  bool isExpanded; // solo aplica a gráficos

  DashboardWidgetConfig({
    required this.id,
    required this.type,
    this.isVisible = true,
    this.order = 0,
    this.isExpanded = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'isVisible': isVisible,
        'order': order,
        'isExpanded': isExpanded,
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
        isExpanded: json['isExpanded'] as bool? ?? false,
      );
}

// ─────────────────────────────────────────────
// Controlador del dashboard (ChangeNotifier)
// ─────────────────────────────────────────────
class DashboardController extends ChangeNotifier {
  static const String _prefsKey = 'dashboard_config_v1';

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

  void toggleExpanded(String id) {
    final w = findById(id);
    if (w == null) return;
    w.isExpanded = !w.isExpanded;
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
