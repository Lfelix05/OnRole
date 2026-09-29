import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../models/venue.dart';
import '../../providers/presence_provider.dart';
import '../../providers/venues_provider.dart';
import '../../services/geo.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/heatmap_layer.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

/// Tiles padrão do OpenStreetMap: gratuitos e sem chave de API, dentro da
/// política de uso (https://operations.osmfoundation.org/policies/tiles/).
const _tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// Transforma o mapa claro do OSM num mapa escuro quase monocromático: cada
/// pixel vira a própria luminância invertida (fundo claro fica escuro, texto
/// escuro fica claro), escalada e puxada para o roxo do tema. Sem as cores do
/// mapa (parques verdes, ruas amarelas), o mapa de calor fica em destaque.
final _darkMapFilter = _buildDarkMapFilter();

ColorFilter _buildDarkMapFilter() {
  // Pesos de luminância (Rec. 709) de R, G e B.
  const luminance = [0.2126, 0.7152, 0.0722];
  // No canal azul, ignorar o azul de entrada deixa a água (azul-claro no OSM)
  // mais azulada que a terra, e o Rio Doce continua visível.
  const blueWeights = [0.5, 0.5, 0.0];

  List<double> channel(double scale, double offset, [List<double> weights = luminance]) => [
        for (final weight in weights) -scale * weight,
        0,
        255 * scale + offset,
      ];

  return ColorFilter.matrix([
    ...channel(0.55, 4),
    ...channel(0.52, 4),
    ...channel(0.72, 12, blueWeights),
    0, 0, 0, 1, 0,
  ]);
}

class _MapScreenState extends State<MapScreen> {
  static const _colatina = LatLng(-19.53477, -40.62870);

  final _mapController = MapController();
  final _searchController = TextEditingController();
  String? _selectedVenueId;
  bool _showHeatmap = true;

  @override
  void dispose() {
    _mapController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _focusVenue(Venue venue) {
    FocusScope.of(context).unfocus();
    _searchController.clear();
    setState(() => _selectedVenueId = venue.id);
    _mapController.move(venue.location, math.max(_mapController.camera.zoom, 16));
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    FocusScope.of(context).unfocus();
    final presence = context.read<PresenceProvider>();
    if (presence.isSimulating) {
      presence.simulateMoveTo(point);
    } else {
      setState(() => _selectedVenueId = null);
    }
  }

  void _centerOnUser() {
    final position = context.read<PresenceProvider>().position;
    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sua localização ainda não está disponível.')),
      );
      return;
    }
    _mapController.move(position, math.max(_mapController.camera.zoom, 16));
  }

  @override
  Widget build(BuildContext context) {
    final venuesProvider = context.watch<VenuesProvider>();
    final presence = context.watch<PresenceProvider>();
    final venues = venuesProvider.venues;
    final selectedVenue = venuesProvider.venueById(_selectedVenueId);
    final checkedInVenue = presence.checkedInVenue;
    final cardVenue = selectedVenue ?? venuesProvider.hottestVenue;
    final userPosition = presence.position;
    final userAccuracy = presence.accuracyMeters;
    final searchResults = venuesProvider.search(_searchController.text);

    // A cerca só aparece no local selecionado e onde o usuário está, para não
    // poluir o mapa.
    final fencedVenues = <Venue>{
      if (selectedVenue != null) selectedVenue,
      if (checkedInVenue != null) checkedInVenue,
    };

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _colatina,
              initialZoom: 15,
              initialCameraFit: venues.isEmpty
                  ? null
                  : CameraFit.bounds(
                      bounds: LatLngBounds.fromPoints([for (final venue in venues) venue.location]),
                      padding: const EdgeInsets.fromLTRB(40, 150, 40, 190),
                      maxZoom: 16,
                    ),
              minZoom: 11,
              maxZoom: 19,
              backgroundColor: AppColors.background,
              // Sem rotação: mapa de calor e pinos ficam sempre "de pé".
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onTap: _onMapTap,
            ),
            children: [
              ColorFiltered(
                colorFilter: _darkMapFilter,
                child: TileLayer(
                  urlTemplate: _tileUrl,
                  // O OSM exige um User-Agent que identifique o app.
                  userAgentPackageName: 'br.com.onrole.app',
                ),
              ),
              if (_showHeatmap)
                HeatmapLayer(
                  points: venuesProvider.heatPoints,
                  saturation: venuesProvider.heatSaturation,
                ),
              CircleLayer(
                circles: [
                  for (final venue in fencedVenues)
                    CircleMarker(
                      point: venue.location,
                      radius: venue.radiusMeters,
                      useRadiusInMeter: true,
                      color: (venue == checkedInVenue ? AppColors.success : AppColors.primary).withValues(alpha: 0.10),
                      borderColor: (venue == checkedInVenue ? AppColors.success : AppColors.primarySoft)
                          .withValues(alpha: 0.8),
                      borderStrokeWidth: 1.5,
                    ),
                  if (userPosition != null && userAccuracy != null)
                    CircleMarker(
                      point: userPosition,
                      radius: userAccuracy,
                      useRadiusInMeter: true,
                      color: AppColors.userLocation.withValues(alpha: 0.12),
                      borderColor: AppColors.userLocation.withValues(alpha: 0.35),
                      borderStrokeWidth: 1,
                    ),
                ],
              ),
              MarkerLayer(
                markers: [
                  // Antes dos pinos: dentro de um local, o número de pessoas
                  // fica visível por cima da posição do usuário.
                  if (userPosition != null)
                    Marker(point: userPosition, width: 22, height: 22, child: const _UserDot()),
                  for (final venue in venues)
                    Marker(
                      point: venue.location,
                      width: 52,
                      height: 52,
                      child: _VenuePin(
                        count: venuesProvider.crowdAt(venue.id),
                        selected: venue == selectedVenue,
                        checkedIn: venue == checkedInVenue,
                        onTap: () => _focusVenue(venue),
                      ),
                    ),
                ],
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SearchField(controller: _searchController, onChanged: (_) => setState(() {})),
                  if (searchResults.isNotEmpty)
                    _SearchResults(
                      venues: searchResults,
                      crowdAt: venuesProvider.crowdAt,
                      onSelected: _focusVenue,
                    )
                  else if (_searchController.text.trim().isNotEmpty)
                    const _SearchEmpty(),
                  const SizedBox(height: 8),
                  const _StatusBanner(),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const _Attribution(),
                    const Spacer(),
                    Column(
                      children: [
                        if (PresenceProvider.simulationAvailable) ...[
                          _MapButton(
                            icon: Icons.science_outlined,
                            tooltip: 'Modo simulação',
                            active: presence.isSimulating,
                            activeColor: AppColors.warning,
                            onPressed: () => presence.setSimulating(!presence.isSimulating),
                          ),
                          const SizedBox(height: 10),
                        ],
                        _MapButton(
                          icon: Icons.local_fire_department_outlined,
                          tooltip: 'Mapa de calor',
                          active: _showHeatmap,
                          onPressed: () => setState(() => _showHeatmap = !_showHeatmap),
                        ),
                        const SizedBox(height: 10),
                        _MapButton(
                          icon: Icons.my_location,
                          tooltip: 'Minha localização',
                          onPressed: _centerOnUser,
                        ),
                      ],
                    ),
                  ],
                ),
                if (cardVenue != null) ...[
                  const SizedBox(height: 12),
                  _VenueCard(
                    venue: cardVenue,
                    crowd: venuesProvider.crowdAt(cardVenue.id),
                    distance: presence.distanceTo(cardVenue),
                    isHottestHighlight: selectedVenue == null,
                    checkedIn: cardVenue == checkedInVenue,
                    onTap: () => _focusVenue(cardVenue),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

IconData _categoryIcon(VenueCategory category) {
  switch (category) {
    case VenueCategory.bar:
      return Icons.local_bar;
    case VenueCategory.balada:
      return Icons.nightlife;
    case VenueCategory.evento:
      return Icons.celebration;
    case VenueCategory.praca:
      return Icons.park;
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 12)],
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Buscar bares, praças, eventos...',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.venues, required this.crowdAt, required this.onSelected});

  final List<Venue> venues;
  final int Function(String venueId) crowdAt;
  final ValueChanged<Venue> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            for (final venue in venues.take(5))
              ListTile(
                dense: true,
                leading: Icon(_categoryIcon(venue.category), color: AppColors.primarySoft),
                title: Text(venue.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  '${crowdAt(venue.id)} pessoas agora · ${venue.category.label}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                onTap: () => onSelected(venue),
              ),
          ],
        ),
      ),
    );
  }
}

class _SearchEmpty extends StatelessWidget {
  const _SearchEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
      child: const Text('Nenhum local encontrado.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
    );
  }
}

/// Faixa sob a busca com o estado mais importante da localização agora.
class _StatusBanner extends StatelessWidget {
  const _StatusBanner();

  @override
  Widget build(BuildContext context) {
    final presence = context.watch<PresenceProvider>();
    final availability = presence.availability;
    final checkedInVenue = presence.checkedInVenue;
    final pending = presence.pendingCheckIn;

    if (!presence.isSimulating && availability != null && availability != LocationAvailability.ready) {
      final (message, actionLabel, action) = switch (availability) {
        LocationAvailability.serviceDisabled => (
            'Ative a localização do aparelho para o check-in automático.',
            'Ativar',
            presence.openSettings,
          ),
        LocationAvailability.deniedForever => (
            'A localização está bloqueada para o OnRolê nas configurações.',
            'Abrir',
            presence.openSettings,
          ),
        _ => (
            'Permita o acesso à localização para o check-in automático.',
            'Permitir',
            presence.retry,
          ),
      };
      return _Banner(
        icon: Icons.location_off_outlined,
        color: AppColors.warning,
        message: message,
        actions: [
          TextButton(onPressed: action, child: Text(actionLabel)),
          if (PresenceProvider.simulationAvailable)
            TextButton(onPressed: () => presence.setSimulating(true), child: const Text('Simular')),
        ],
      );
    }

    if (checkedInVenue != null) {
      return _Banner(
        icon: Icons.check_circle,
        color: AppColors.success,
        message: 'Você está no rolê: ${checkedInVenue.name}',
      );
    }

    if (pending != null) {
      return _Banner(
        icon: Icons.radar,
        color: AppColors.primarySoft,
        message: 'Confirmando sua presença em ${pending.venue.name}...',
        progress: pending.progress,
      );
    }

    if (presence.isSimulating) {
      return _Banner(
        icon: Icons.touch_app_outlined,
        color: AppColors.warning,
        message: presence.position == null
            ? 'Simulação: toque no mapa para definir sua posição.'
            : 'Simulação: toque no mapa para mover sua posição.',
      );
    }

    return const SizedBox.shrink();
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.color,
    required this.message,
    this.actions = const [],
    this.progress,
  });

  final IconData icon;
  final Color color;
  final String message;
  final List<Widget> actions;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 13)),
              ),
              ...actions,
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                color: color,
                backgroundColor: AppColors.border,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VenuePin extends StatelessWidget {
  const _VenuePin({
    required this.count,
    required this.selected,
    required this.checkedIn,
    required this.onTap,
  });

  final int count;
  final bool selected;
  final bool checkedIn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = selected ? 44.0 : 34.0;
    final ringColor = checkedIn ? AppColors.success : (selected ? Colors.white : null);

    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            shape: BoxShape.circle,
            border: ringColor == null ? null : Border.all(color: ringColor, width: 2.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          child: Text(
            '$count',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ),
    );
  }
}

class _UserDot extends StatelessWidget {
  const _UserDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.userLocation,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [BoxShadow(color: AppColors.userLocation.withValues(alpha: 0.6), blurRadius: 10)],
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
    this.activeColor = AppColors.primary,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool active;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? activeColor : AppColors.surface,
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: active ? Colors.white : AppColors.textSecondary, size: 22),
          ),
        ),
      ),
    );
  }
}

/// Crédito exigido pela licença dos dados do OpenStreetMap (ODbL).
class _Attribution extends StatelessWidget {
  const _Attribution();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        '© OpenStreetMap contributors',
        style: TextStyle(color: AppColors.textTertiary, fontSize: 10),
      ),
    );
  }
}

class _VenueCard extends StatelessWidget {
  const _VenueCard({
    required this.venue,
    required this.crowd,
    required this.distance,
    required this.isHottestHighlight,
    required this.checkedIn,
    required this.onTap,
  });

  final Venue venue;
  final int crowd;
  final double? distance;
  final bool isHottestHighlight;
  final bool checkedIn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final details = [
      '$crowd pessoas agora',
      if (distance != null) formatDistance(distance!),
      venue.category.label,
    ].join(' · ');

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      elevation: 6,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_categoryIcon(venue.category), color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isHottestHighlight)
                      const Text(
                        'MAIS MOVIMENTADO AGORA',
                        style: TextStyle(
                          color: AppColors.primarySoft,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    Text(venue.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(details, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    if (checkedIn) ...[
                      const SizedBox(height: 2),
                      const Text(
                        'Você está aqui',
                        style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
