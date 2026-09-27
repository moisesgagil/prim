import 'package:flutter/material.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:primware/shared/custom_container.dart';
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

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  DateTime? lastBackPressed;
  bool _isLoading = true;

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
        _salesYTDBySalesRepLoader(context: context, offset: 0).then((value) {
          ytdData = value;
        }),
      );
    }

    if (Charts.salesPerDayByProductCategory != null && productCategoryData.isEmpty) {
      futures.add(
        _salesPerDayByProductCategoryLoader(context: context, offset: 0).then((value) {
          productCategoryData = value;
        }),
      );
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }

    if (!mounted) return;

    setState(() {
      _salesYTDBySalesRepData = ytdData;
      _salesPerDayByProductCategoryData = productCategoryData;
      _isLoading = false;
    });
  }

  // ─── Helpers de localización de meses ─────────────────────────────────────
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
                  // Handle
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
                          onTap: () {
                            _dashCtrl.showWidget(cfg.id);
                          },
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
                        final label = cfg.id == WidgetId.chartSalesYTD
                            ? 'Ventas YTD por Rep.'
                            : 'Ventas por Categoría';
                        return GestureDetector(
                          onTap: () {
                            _dashCtrl.showWidget(cfg.id);
                          },
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
                  // Botón reset
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

  // ─── Ancho máximo del contenedor según tamaño de pantalla ─────────────────
  double _maxContainerWidth(double screenWidth) {
    if (screenWidth >= 1400) return 1320;
    if (screenWidth >= 1100) return 1040;
    if (screenWidth >= 900) return 860;
    if (screenWidth >= 700) return screenWidth - 48;
    return screenWidth; // móvil: sin límite lateral
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
                // Botón Modo Edición
                Tooltip(
                  message: editMode ? 'Salir del modo edición' : 'Personalizar dashboard',
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 4),
                    child: IconButton(
                      icon: Icon(
                        editMode ? Icons.edit_off : Icons.edit_outlined,
                        color: editMode ? Theme.of(context).colorScheme.primary : null,
                      ),
                      onPressed: _dashCtrl.toggleEditMode,
                    ),
                  ),
                ),
                const ThemeToggleIconButton(),
                !isMobile ? LogoPill() : const SizedBox.shrink(),
              ],
            ),
            bottomNavigationBar: const CustomFooter(),
            drawer: const MenuDrawer(),

            // FAB: Añadir Widgets (solo en modo edición)
            floatingActionButton: editMode
                ? FloatingActionButton.extended(
                    onPressed: _showAddWidgetSheet,
                    icon: const Icon(Icons.add),
                    label: const Text('Añadir widget'),
                  )
                : null,

            body: SafeArea(
              child: _isLoading
                  ? const DashboardSkeleton()
                  : SingleChildScrollView(
                      child: Center(
                        child: CustomContainer(
                          maxWidthContainer: _maxContainerWidth(MediaQuery.of(context).size.width),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── Botón Mis Órdenes ──────────────────────
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

                                // ── Sección KPIs ───────────────────────────
                                _buildKpiSection(editMode, isMobile),
                                const SizedBox(height: CustomSpacer.medium),

                                // ── Sección Gráficos ───────────────────────
                                _buildChartSection(editMode),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }

  // ─── Sección KPIs con drag & drop ─────────────────────────────────────────
  Widget _buildKpiSection(bool editMode, bool isMobile) {
    final visibleKpis = _dashCtrl.visibleKpis;

    if (visibleKpis.isEmpty && !editMode) return const SizedBox.shrink();

    final double kpiWidth = isMobile ? 160.0 : 180.0;
    const double kpiHeight = 110.0;

    // En modo edición mostramos el encabezado de sección
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (editMode) ...[
          Row(
            children: [
              Icon(Icons.drag_indicator, size: 16, color: Theme.of(context).colorScheme.primary.withOpacity(0.7)),
              const SizedBox(width: 6),
              Text(
                'KPIs — Arrastra para reordenar',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],

        if (visibleKpis.isEmpty)
          _emptySection('No hay KPIs visibles.\nToca "Añadir widget" para agregar.')
        else
          SizedBox(
            height: kpiHeight + 16, // margen extra para el botón X que sobresale
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              buildDefaultDragHandles: false,
              physics: const BouncingScrollPhysics(),
              onReorder: _dashCtrl.reorderKpis,
              itemCount: visibleKpis.length,
              proxyDecorator: (child, index, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (ctx, c) => Material(
                    elevation: 8 * animation.value,
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    child: c,
                  ),
                  child: child,
                );
              },
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
                      top: 10, // espacio para el botón X que sobresale arriba
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

  // ─── Sección Gráficos con drag & drop ─────────────────────────────────────
  Widget _buildChartSection(bool editMode) {
    final visibleCharts = _dashCtrl.visibleCharts;

    if (visibleCharts.isEmpty && !editMode) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (editMode) ...[
          Row(
            children: [
              Icon(Icons.drag_indicator, size: 16, color: Theme.of(context).colorScheme.primary.withOpacity(0.7)),
              const SizedBox(width: 6),
              Text(
                'Gráficos — Arrastra para reordenar',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],

        if (visibleCharts.isEmpty)
          _emptySection('No hay gráficos visibles.\nToca "Añadir widget" para agregar.')
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorder: _dashCtrl.reorderCharts,
            itemCount: visibleCharts.length,
            proxyDecorator: (child, index, animation) {
              return AnimatedBuilder(
                animation: animation,
                builder: (ctx, c) => Material(
                  elevation: 8 * animation.value,
                  color: Colors.transparent,
                  child: c,
                ),
                child: child,
              );
            },
            itemBuilder: (ctx, index) {
              final cfg = visibleCharts[index];
              return _buildChartItem(cfg, index, editMode);
            },
          ),
      ],
    );
  }

  // ─── Ítem de gráfico individual ────────────────────────────────────────────
  Widget _buildChartItem(DashboardWidgetConfig cfg, int index, bool editMode) {
    final lang = Localizations.localeOf(context).languageCode;
    final isExpanded = cfg.isExpanded;

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

    // Si el endpoint del gráfico no está habilitado, no mostramos nada
    if (chartWidget == null) return SizedBox(key: ValueKey(cfg.id));

    return Padding(
      key: ValueKey(cfg.id),
      padding: EdgeInsets.only(bottom: index > 0 ? CustomSpacer.medium : 0),
      child: Stack(
        children: [
          // Wrapper animado para la altura (expandir/contraer)
          AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeInOut,
            constraints: BoxConstraints(
              minHeight: 0,
              maxHeight: isExpanded ? 640 : 420,
            ),
            child: OverflowBox(
              maxHeight: double.infinity,
              alignment: Alignment.topCenter,
              child: chartWidget,
            ),
          ),

          // Barra de controles en modo edición
          if (editMode)
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  ReorderableDragStartListener(
                    index: index,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.drag_indicator,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Expandir / Contraer
                  GestureDetector(
                    onTap: () => _dashCtrl.toggleExpanded(cfg.id),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isExpanded ? Icons.fullscreen_exit : Icons.fullscreen,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Ocultar
                  GestureDetector(
                    onTap: () => _dashCtrl.hideWidget(cfg.id),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade400,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.close, size: 18, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─── Widget de sección vacía ───────────────────────────────────────────────
  Widget _emptySection(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.3),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.widgets_outlined, size: 32, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }
}
