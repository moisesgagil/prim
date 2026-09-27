import 'package:flutter/material.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:primware/shared/logo_pill.dart';
import 'package:primware/shared/theme_switcher_controller.dart';
import 'package:primware/views/Home/dashboard/dashboard_skeleton.dart';
import '../../../API/endpoint.dart';
import '../../../API/pos.api.dart';
import '../../../API/token.api.dart';
import '../../../API/user.api.dart';
import '../../../shared/custom_app_menu.dart';
import '../../../shared/custom_spacer.dart';
import '../../../shared/footer.dart';
import '../../Auth/login_view.dart';
import 'password_warning_dialog.dart';
import 'dashboard_graph.dart';
import 'dashboard_funtions.dart';
import '../../../localization/app_locale.dart';
import '../order/my_order.dart';
import 'dashboard_kpi_card.dart';
import 'dashboard_config.dart';
import 'package:reorderables/reorderables.dart';

// ─── Datos de ejemplo de KPIs ────────────────────────────────────────────────
// TODO: Reemplazar con datos reales desde el endpoint de dashboard KPIs
class _KpiData {
  static const Map<String, Map<String, dynamic>> mock = {
    WidgetId.kpiSalesMonth: {
      'title': 'Ventas (Mes)',
      'value': '\$45K',
      'subtitle': null,
      'icon': Icons.trending_up,
      'color': Colors.green,
    },
    WidgetId.kpiOrdersToday: {
      'title': 'Órdenes (Hoy)',
      'value': '24',
      'subtitle': null,
      'icon': Icons.receipt_long,
      'color': null,
    },
    WidgetId.kpiAvgTicket: {
      'title': 'Productos Vendidos',
      'value': '138',
      'subtitle': null,
      'icon': Icons.inventory_2_outlined,
      'color': null,
    },
    WidgetId.kpiReturns: {
      'title': 'Devoluciones',
      'value': '2',
      'subtitle': null,
      'icon': Icons.assignment_return,
      'color': Colors.red,
    },
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget de gráfico redimensionable por arrastre
// ─────────────────────────────────────────────────────────────────────────────
class _ResizableChartCard extends StatefulWidget {
  final Widget child;
  final double initialHeight;
  final double initialWidthFactor;
  final double parentWidth;
  final bool editMode;
  final bool isMobile;
  final ValueChanged<double> onHeightChanged;
  final ValueChanged<double> onWidthFactorChanged;

  const _ResizableChartCard({
    required this.child,
    required this.initialHeight,
    required this.initialWidthFactor,
    required this.parentWidth,
    required this.editMode,
    required this.isMobile,
    required this.onHeightChanged,
    required this.onWidthFactorChanged,
  });

  @override
  State<_ResizableChartCard> createState() => _ResizableChartCardState();
}

class _ResizableChartCardState extends State<_ResizableChartCard> {
  late double _height;
  late double _widthFactor;
  bool _isDraggingHeight = false;
  bool _isDraggingWidth = false;

  @override
  void initState() {
    super.initState();
    _height = widget.initialHeight;
    _widthFactor = widget.initialWidthFactor;
  }

  @override
  void didUpdateWidget(_ResizableChartCard old) {
    super.didUpdateWidget(old);
    if (!_isDraggingHeight && old.initialHeight != widget.initialHeight) _height = widget.initialHeight;
    if (!_isDraggingWidth && old.initialWidthFactor != widget.initialWidthFactor) _widthFactor = widget.initialWidthFactor;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final editMode = widget.editMode;

    return AnimatedContainer(
      duration: (_isDraggingHeight || _isDraggingWidth) ? Duration.zero : const Duration(milliseconds: 200),
      height: _height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: editMode
            ? Border.all(color: cs.primary.withOpacity(0.4), width: 1.5)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Contenido del gráfico — ocupa toda la altura disponible
          Positioned.fill(child: widget.child),

          // Handle de redimensionado de altura (inferior)
          if (editMode)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragStart: (_) => setState(() => _isDraggingHeight = true),
                onVerticalDragUpdate: (d) {
                  setState(() {
                    _height = (_height + d.delta.dy).clamp(
                      DashboardWidgetConfig.minChartHeight,
                      DashboardWidgetConfig.maxChartHeight,
                    );
                  });
                },
                onVerticalDragEnd: (_) {
                  setState(() => _isDraggingHeight = false);
                  widget.onHeightChanged(_height);
                },
                child: Container(
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        cs.surface.withOpacity(0),
                        cs.surface.withOpacity(0.95),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(color: cs.primary.withOpacity(0.6), borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                ),
              ),
            ),

          // Handle de redimensionado de ancho (derecho)
          if (editMode && !widget.isMobile)
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) => setState(() => _isDraggingWidth = true),
                onHorizontalDragUpdate: (d) {
                  setState(() {
                    double currentPx = _widthFactor * widget.parentWidth;
                    _widthFactor = ((currentPx + d.delta.dx) / widget.parentWidth).clamp(0.2, 1.0);
                  });
                  widget.onWidthFactorChanged(_widthFactor);
                },
                onHorizontalDragEnd: (_) {
                  setState(() => _isDraggingWidth = false);
                  widget.onWidthFactorChanged(_widthFactor);
                },
                child: Container(
                  width: 28,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        cs.surface.withOpacity(0),
                        cs.surface.withOpacity(0.95),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Container(
                      height: 48,
                      width: 5,
                      decoration: BoxDecoration(color: cs.primary.withOpacity(0.6), borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                ),
              ),
            ),

          // Indicador de altura/ancho durante el drag
          if (_isDraggingHeight || _isDraggingWidth)
            Positioned(
              top: 8,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_height.toInt()} px  •  ${(_widthFactor * 100).toInt()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Página principal del Dashboard
// ─────────────────────────────────────────────────────────────────────────────
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  DateTime? lastBackPressed;
  bool _isLoading = true;

  // Variables para reordenamiento de gráficos
  String? _draggingChartId;
  int? _hoverChartIndex;

  Map<String, double> _salesYTDBySalesRepData = {};
  Map<String, double> _salesPerDayByProductCategoryData = {};

  late final ChartDataLoader _salesYTDBySalesRepLoader;
  late final ChartDataLoader _salesPerDayByProductCategoryLoader;

  final DashboardController _dashCtrl = DashboardController();

  @override
  void initState() {
    super.initState();

    _salesYTDBySalesRepLoader = ({required context, required int offset}) =>
        fetchSalesYTDBySalesRepCurrentMonth(context: context, monthOffset: offset);
    _salesPerDayByProductCategoryLoader = ({required context, required int offset}) =>
        fetchSalesPerDayByProductCategory(context: context, dayOffset: offset);

    _dashCtrl.load().then((_) => _checkDashboardData());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (usuarioController.text.trim() == claveController.text.trim() &&
          usuarioController.text.trim().isNotEmpty) {
        PasswordWarningDialog.show(context);
      }
    });
  }

  @override
  void dispose() {
    _dashCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkDashboardData() async {
    setState(() => _isLoading = true);

    Map<String, double> ytdData = _salesYTDBySalesRepData;
    Map<String, double> productCategoryData = _salesPerDayByProductCategoryData;

    final List<Future<void>> futures = [];

    if (Charts.salesYTDBySalesRep != null && ytdData.isEmpty) {
      futures.add(
        _salesYTDBySalesRepLoader(context: context, offset: 0).then((v) => ytdData = v),
      );
    }
    if (Charts.salesPerDayByProductCategory != null && productCategoryData.isEmpty) {
      futures.add(
        _salesPerDayByProductCategoryLoader(context: context, offset: 0)
            .then((v) => productCategoryData = v),
      );
    }

    if (futures.isNotEmpty) await Future.wait(futures);
    if (!mounted) return;

    setState(() {
      _salesYTDBySalesRepData = ytdData;
      _salesPerDayByProductCategoryData = productCategoryData;
      _isLoading = false;
    });
  }

  // ─── Helper: nombre de mes localizado ─────────────────────────────────────
  String _monthName(int month, String lang) {
    const es = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    const en = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return lang == 'es' ? es[month - 1] : en[month - 1];
  }

  // ─── Panel inferior: Añadir Widgets ───────────────────────────────────────
  void _showAddWidgetSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return AnimatedBuilder(
          animation: _dashCtrl,
          builder: (context, _) {
            final hiddenKpis = _dashCtrl.hiddenKpis;
            final hiddenCharts = _dashCtrl.hiddenCharts;

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Añadir widgets al dashboard',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Toca un widget para volver a mostrarlo.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                        ),
                  ),
                  const SizedBox(height: 20),

                  if (hiddenKpis.isEmpty && hiddenCharts.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            Icon(Icons.check_circle_outline, size: 48, color: Colors.green.withOpacity(0.6)),
                            const SizedBox(height: 12),
                            Text(
                              'Todos los widgets están visibles',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.5),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (hiddenKpis.isNotEmpty) ...[
                    Text('KPIs', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: hiddenKpis.map((cfg) {
                        final data = _KpiData.mock[cfg.id];
                        return GestureDetector(
                          onTap: () => _dashCtrl.showWidget(cfg.id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(data?['icon'] as IconData? ?? Icons.bar_chart, size: 16, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 8),
                                Text(data?['title'] as String? ?? cfg.id, style: const TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(width: 6),
                                Icon(Icons.add_circle_outline, size: 16, color: Theme.of(context).colorScheme.primary),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  if (hiddenCharts.isNotEmpty) ...[
                    Text('Gráficos', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: hiddenCharts.map((cfg) {
                        final label = cfg.id == WidgetId.chartSalesYTD ? 'Ventas YTD por Rep.' : 'Ventas por Categoría';
                        return GestureDetector(
                          onTap: () => _dashCtrl.showWidget(cfg.id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.insert_chart_outlined, size: 16, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 8),
                                Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(width: 6),
                                Icon(Icons.add_circle_outline, size: 16, color: Theme.of(context).colorScheme.primary),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      _dashCtrl.resetToDefaults();
                      Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.restart_alt, size: 18),
                    label: const Text('Restablecer a predeterminado'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 700;

    return WillPopScope(
      onWillPop: () async {
        final now = DateTime.now();
        if (lastBackPressed == null || now.difference(lastBackPressed!) > const Duration(seconds: 2)) {
          lastBackPressed = now;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocale.pressAgainToLogout.getString(context)), duration: const Duration(seconds: 2)),
          );
          return false;
        }
        Token.auth = null;
        Token.adOrgInfoUU = null;
        POS.bankAccountID = null;
        usuarioController.clear();
        claveController.clear();
        UserData.rolName = null;
        UserData.imageBytes = null;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
        return false;
      },
      child: AnimatedBuilder(
        animation: _dashCtrl,
        builder: (context, _) {
          final editMode = _dashCtrl.editMode;

          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocale.dashboard.getString(context)),
              actions: [
                Tooltip(
                  message: editMode ? 'Salir del modo edición' : 'Personalizar dashboard',
                  child: IconButton(
                    icon: Icon(
                      editMode ? Icons.edit_off : Icons.edit_outlined,
                    ),
                    onPressed: _dashCtrl.toggleEditMode,
                  ),
                ),
                const ThemeToggleIconButton(),
                !isMobile ? LogoPill() : const SizedBox.shrink(),
              ],
            ),
            bottomNavigationBar: const CustomFooter(),
            drawer: const MenuDrawer(),
            floatingActionButton: editMode
                ? FloatingActionButton.extended(
                    onPressed: _showAddWidgetSheet,
                    icon: const Icon(Icons.add),
                    label: const Text('Añadir widget'),
                  )
                : null,
            body: GestureDetector(
              onTap: () {
                if (editMode) _dashCtrl.setEditMode(false);
              },
              behavior: HitTestBehavior.translucent,
              child: SafeArea(
                child: _isLoading
                    ? const DashboardSkeleton()
                    : SingleChildScrollView(
                      // ── El padding horizontal da "aire" pero NO hay maxWidth
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 8 : 20,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Botón Mis Órdenes ──────────────────────────
                          SizedBox(
                            width: double.infinity,
                            child: TextButton.icon(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: Icon(Icons.list_alt, size: 20, color: Theme.of(context).colorScheme.secondary),
                              label: Text(
                                AppLocale.myOrders.getString(context),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.secondary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const OrderListPage()));
                              },
                            ),
                          ),
                          const SizedBox(height: CustomSpacer.medium),

                          // ── KPIs ────────────────────────────────────────
                          _buildKpiSection(editMode, isMobile),
                          const SizedBox(height: CustomSpacer.medium),

                          // ── Gráficos ─────────────────────────────────────
                          _buildChartSection(editMode),

                          // Espacio al fondo para que el FAB no tape nada
                          if (editMode) const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      }

  // ─── Sección KPIs ─────────────────────────────────────────────────────────
  Widget _buildKpiSection(bool editMode, bool isMobile) {
    final visibleKpis = _dashCtrl.visibleKpis;
    if (visibleKpis.isEmpty && !editMode) return const SizedBox.shrink();

    const double kpiWidth = 170.0;
    const double kpiHeight = 100.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (editMode) _sectionLabel('KPIs — Arrastra para reordenar'),

        if (visibleKpis.isEmpty)
          _emptySection('No hay KPIs visibles.\nToca "Añadir widget" para agregar.')
        else
          SizedBox(
            height: kpiHeight + 12, // +12 para el botón X que sobresale arriba
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              buildDefaultDragHandles: false,
              physics: const BouncingScrollPhysics(),
              onReorder: _dashCtrl.reorderKpis,
              itemCount: visibleKpis.length,
              proxyDecorator: (child, index, animation) => AnimatedBuilder(
                animation: animation,
                builder: (ctx, c) => Material(
                  elevation: 8 * animation.value,
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  child: c,
                ),
                child: child,
              ),
              itemBuilder: (ctx, index) {
                final cfg = visibleKpis[index];
                final data = _KpiData.mock[cfg.id];

                return ReorderableDragStartListener(
                  key: ValueKey(cfg.id),
                  index: index,
                  enabled: editMode,
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: index < visibleKpis.length - 1 ? 12 : 0,
                      top: 10,
                    ),
                    child: SizedBox(
                      width: kpiWidth,
                      height: kpiHeight,
                      child: DashboardKpiCard(
                        title: data?['title'] as String? ?? cfg.id,
                        value: data?['value'] as String? ?? '—',
                        subtitle: data?['subtitle'] as String?,
                        icon: data?['icon'] as IconData?,
                        valueColor: data?['color'] as Color?,
                        editMode: editMode,
                        onRemove: editMode ? () => _dashCtrl.hideWidget(cfg.id) : null,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ─── Sección Gráficos ──────────────────────────────────────────────────────
  Widget _buildChartSection(bool editMode) {
    final visibleCharts = _dashCtrl.visibleCharts;
    if (visibleCharts.isEmpty && !editMode) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (editMode) _sectionLabel('Gráficos — Arrastra el icono para mover · Arrastra el borde inferior para redimensionar'),

        if (visibleCharts.isEmpty)
          _emptySection('No hay gráficos visibles.\nToca "Añadir widget" para agregar.')
        else
          Builder(
            builder: (context) {
              // 1. Clonar lista para la reordenación visual en tiempo real
              List<DashboardWidgetConfig> displayList = List.from(visibleCharts);

              if (editMode && _draggingChartId != null && _hoverChartIndex != null) {
                final draggingItem = displayList.firstWhere((c) => c.id == _draggingChartId, orElse: () => displayList.first);
                displayList.removeWhere((c) => c.id == _draggingChartId);
                
                int insertIndex = _hoverChartIndex!;
                if (insertIndex > displayList.length) insertIndex = displayList.length;
                
                displayList.insert(insertIndex, draggingItem);
              }

              return Wrap(
                spacing: CustomSpacer.medium,
                runSpacing: CustomSpacer.medium,
                children: displayList.asMap().entries.map((entry) {
                  final index = entry.key;
                  final cfg = entry.value;

                  final child = _buildChartItem(cfg, editMode, isGhost: cfg.id == _draggingChartId);

                  if (!editMode) return child;

                  return DragTarget<String>(
                    onWillAcceptWithDetails: (details) {
                      if (details.data != cfg.id) {
                        setState(() => _hoverChartIndex = index);
                        return true;
                      }
                      return false;
                    },
                    onAcceptWithDetails: (details) {
                      final oldIndex = visibleCharts.indexWhere((c) => c.id == details.data);
                      if (oldIndex != -1) {
                        _dashCtrl.reorderCharts(oldIndex, index);
                      }
                      setState(() {
                        _draggingChartId = null;
                        _hoverChartIndex = null;
                      });
                    },
                    builder: (context, candidateData, rejectedData) {
                      return child;
                    },
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }

  // ─── Ítem de gráfico individual ────────────────────────────────────────────
  Widget _buildChartItem(DashboardWidgetConfig cfg, bool editMode, {bool isGhost = false}) {
    final lang = Localizations.localeOf(context).languageCode;
    final bool isMobile = MediaQuery.of(context).size.width < 700;
    
    // Cálculo del ancho dinámico
    final double paddingHorizontal = isMobile ? 16 : 40;
    final double parentWidth = MediaQuery.of(context).size.width - paddingHorizontal;
    final double spacing = CustomSpacer.medium;
    
    // En móviles forzamos a 100% (factor 1.0) para que no se vea apretado.
    final double activeWidthFactor = isMobile ? 1.0 : cfg.chartWidthFactor;
    
    double itemWidth = parentWidth;
    if (activeWidthFactor < 1.0) {
      itemWidth = (parentWidth * activeWidthFactor) - (spacing / 2);
    }

    Widget? chartWidget;
    if (cfg.id == WidgetId.chartSalesYTD && Charts.salesYTDBySalesRep != null) {
      chartWidget = GraphicBarMetricCard(
        titleBuilder: (ctx, offset) {
          if (offset == 0) return AppLocale.thisMonth.getString(context);
          final now = DateTime.now();
          final d = DateTime(now.year, now.month + offset, 1);
          return '${_monthName(d.month, lang)} ${d.year}';
        },
        initialData: _salesYTDBySalesRepData,
        dataLoader: _salesYTDBySalesRepLoader,
        subtitle: AppLocale.salesYTDBySalesRepDescription.getString(context),
        showTotal: true,
      );
    } else if (cfg.id == WidgetId.chartSalesCategory && Charts.salesPerDayByProductCategory != null) {
      chartWidget = GraphicPieMetricCard(
        titleBuilder: (ctx, offset) {
          if (offset == 0) return AppLocale.today.getString(ctx);
          if (offset == -1) return AppLocale.yesterday.getString(ctx);
          final now = DateTime.now();
          final d = DateTime(now.year, now.month, now.day).add(Duration(days: offset));
          return '${d.day} de ${_monthName(d.month, lang)}';
        },
        initialData: _salesPerDayByProductCategoryData,
        dataLoader: _salesPerDayByProductCategoryLoader,
        subtitle: AppLocale.todaySalesByCategoryDescription.getString(context),
        showTotal: true,
      );
    }

    if (chartWidget == null) return SizedBox(key: ValueKey(cfg.id));

    Widget chartBox = Stack(
      clipBehavior: Clip.none,
      children: [
        // Gráfico con resize handle
        _ResizableChartCard(
          initialHeight: cfg.chartHeight,
          initialWidthFactor: cfg.chartWidthFactor,
          parentWidth: parentWidth,
          editMode: editMode,
          isMobile: isMobile,
          onHeightChanged: (h) => _dashCtrl.setChartHeight(cfg.id, h),
          onWidthFactorChanged: (w) => _dashCtrl.setChartWidth(cfg.id, w),
          child: AbsorbPointer(
            absorbing: editMode,
            child: chartWidget,
          ),
        ),

        // Controles flotantes en modo edición (esquina superior derecha)
        if (editMode)
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isMobile) ...[
                  _controlButton(
                    icon: Icons.format_align_left,
                    tooltip: 'Alinear a la izquierda',
                    color: cfg.chartAlignment == 'left' ? Theme.of(context).colorScheme.primary : null,
                    onTap: () => _dashCtrl.setChartAlignment(cfg.id, 'left'),
                  ),
                  const SizedBox(width: 6),
                  _controlButton(
                    icon: Icons.format_align_center,
                    tooltip: 'Centrar',
                    color: cfg.chartAlignment == 'center' ? Theme.of(context).colorScheme.primary : null,
                    onTap: () => _dashCtrl.setChartAlignment(cfg.id, 'center'),
                  ),
                  const SizedBox(width: 6),
                  _controlButton(
                    icon: Icons.format_align_right,
                    tooltip: 'Alinear a la derecha',
                    color: cfg.chartAlignment == 'right' ? Theme.of(context).colorScheme.primary : null,
                    onTap: () => _dashCtrl.setChartAlignment(cfg.id, 'right'),
                  ),
                  const SizedBox(width: 6),
                ],
                
                // Drag handle para reordenar
                Draggable<String>(
                  data: cfg.id,
                  onDragStarted: () {
                    setState(() {
                      _draggingChartId = cfg.id;
                      _hoverChartIndex = _dashCtrl.visibleCharts.indexWhere((c) => c.id == cfg.id);
                    });
                  },
                  onDraggableCanceled: (_, __) {
                    setState(() {
                      _draggingChartId = null;
                      _hoverChartIndex = null;
                    });
                  },
                  onDragCompleted: () {
                    setState(() {
                      _draggingChartId = null;
                      _hoverChartIndex = null;
                    });
                  },
                  feedback: Material(
                    type: MaterialType.transparency,
                    child: SizedBox(
                      width: itemWidth,
                      height: cfg.chartHeight,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                        ),
                        child: _buildChartItem(cfg, false),
                      ),
                    ),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.3,
                    child: _controlButton(icon: Icons.drag_indicator),
                  ),
                  child: _controlButton(icon: Icons.drag_indicator),
                ),
                const SizedBox(width: 6),
                // Ocultar gráfico
                _controlButton(
                  icon: Icons.close,
                  tooltip: 'Ocultar gráfico',
                  color: Colors.red.shade400,
                  onTap: () => _dashCtrl.hideWidget(cfg.id),
                ),
              ],
            ),
          ),
      ],
    );

    if (!isMobile && cfg.chartAlignment != 'left') {
      return Container(
        key: ValueKey(cfg.id),
        width: parentWidth,
        alignment: cfg.chartAlignment == 'center' ? Alignment.center : Alignment.centerRight,
        child: Opacity(
          opacity: isGhost ? 0.3 : 1.0,
          child: SizedBox(
            width: itemWidth,
            child: chartBox,
          ),
        ),
      );
    }

    return Opacity(
      opacity: isGhost ? 0.3 : 1.0,
      child: SizedBox(
        key: ValueKey(cfg.id),
        width: itemWidth,
        child: chartBox,
      ),
    );
  }

  // ─── Helpers de UI ─────────────────────────────────────────────────────────
  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.drag_indicator, size: 15, color: Theme.of(context).colorScheme.primary.withOpacity(0.7)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    String? tooltip,
    Color? color,
    VoidCallback? onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    
    Widget content = Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: color ?? cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4)],
      ),
      child: Icon(icon, size: 17, color: color != null ? Colors.white : cs.primary),
    );

    if (tooltip != null) {
      content = Tooltip(
        message: tooltip,
        child: content,
      );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }

  Widget _emptySection(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.widgets_outlined, size: 32, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
          ),
        ],
      ),
    );
  }
}
