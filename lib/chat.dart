import 'dart:async';

import 'package:flutter/material.dart';
import 'app_routes.dart';
import 'chat/chat_controller.dart';
import 'chat/chat_message_dto.dart';
import 'chat/chat_state.dart';
import 'permissions/permissions_controller.dart';
import 'permissions/permissions_state.dart';
import 'quick_status_models.dart';

class ChatPage extends StatefulWidget {
	const ChatPage({super.key, this.initialArgs});

	final ChatRouteArgs? initialArgs;

	@override
	State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
	final ChatController _controller = ChatController();
	final PermissionsController _permissionsController = PermissionsController(includeMicrophone: true);
	final TextEditingController _filterController = TextEditingController();
	Timer? _statusTickTimer;
	bool _initialized = false;
	String _filterText = '';

	static const Color _bg = Color(0xFF07090D);
	static const Color _amber = Color(0xFFF7B21A);

	@override
	void didChangeDependencies() {
		super.didChangeDependencies();
		if (_initialized) return;
		_initialized = true;
		final routeArgs = widget.initialArgs ?? AppRoutes.chatArgsOf(ModalRoute.of(context)?.settings.arguments);
		_controller.init(routeArgs);
		_permissionsController.init();
		_statusTickTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
			if (!mounted) return;
			setState(() {});
		});
	}

	@override
	void dispose() {
		_statusTickTimer?.cancel();
		_filterController.dispose();
		_permissionsController.dispose();
		_controller.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		return StreamBuilder<PermissionsState>(
			stream: _permissionsController.stateStream,
			initialData: _permissionsController.state,
			builder: (context, permSnapshot) {
				final PermissionsState permState = permSnapshot.data ?? _permissionsController.state;
				return StreamBuilder<ChatState>(
					stream: _controller.stateStream,
					initialData: _controller.state,
					builder: (context, snapshot) {
						final ChatState viewState = snapshot.data ?? _controller.state;

						// Group only actual chat messages; connection status has its own card.
						final Map<String, List<ChatMessageDto>> byPeer = {};
						for (final ChatMessageDto msg in viewState.messages) {
							final String key;
							if (msg.outgoing) {
								key = viewState.session.peerId ?? viewState.session.peerName ?? 'ACTIVE_DEVICE';
							} else {
								key = msg.peerId ?? msg.senderId ?? viewState.session.peerId ?? 'UNKNOWN_DEVICE';
							}
							byPeer.putIfAbsent(key, () => []).add(msg);
						}

						// Apply filter
						Map<String, List<ChatMessageDto>> filtered = byPeer;
						if (_filterText.isNotEmpty) {
							final String q = _filterText.toUpperCase();
							filtered = Map.fromEntries(
								byPeer.entries.where((e) {
									final String display = _displayNameForPeer(e.key, viewState).toUpperCase();
									return display.contains(q) || e.key.toUpperCase().contains(q);
								}),
							);
						}

						final bool hasConversations = filtered.isNotEmpty;

						return Scaffold(
							backgroundColor: _bg,
							body: SafeArea(
								bottom: true,
								child: Stack(
									children: [
										Column(
											children: [
												_topBar(),
												if (!permState.canUseMeshActions || !permState.canUseLocationActions)
													_permissionBanner(permState),
												_filterBar(),
												_statusLinkCard(viewState),
												Expanded(
													child: hasConversations
														? _conversationsList(viewState, filtered)
														: _emptyState(),
												),
												_bottomNav(context),
											],
										),
										Positioned(
											right: 16,
											bottom: 86 + 16,
											child: _fab(context),
										),
									],
								),
							),
						);
					},
				);
			},
		);
	}

	Widget _topBar() {
		return Container(
			height: 78,
			color: const Color(0xFF0F1218),
			padding: const EdgeInsets.symmetric(horizontal: 16),
			child: Row(
				children: [
					Icon(Icons.navigation, color: _amber, size: 20),
					const SizedBox(width: 8),
					const Text(
						'BLACKOUT LINK',
						style: TextStyle(
							color: Color(0xFFF7B21A),
							fontSize: 26,
							fontWeight: FontWeight.w900,
							letterSpacing: 0.5,
							height: 1,
						),
					),
					const Spacer(),
					const Icon(Icons.search, color: Color(0xFFA8ADB8), size: 26),
					const SizedBox(width: 18),
					const Icon(Icons.settings, color: Color(0xFFA8ADB8), size: 26),
				],
			),
		);
	}

	Widget _permissionBanner(PermissionsState permissions) {
		return Container(
			width: double.infinity,
			padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
			color: const Color(0x33EF242B),
			child: Row(
				children: [
					Expanded(
						child: Text(
							permissions.toBannerMessage(includeMicrophone: true),
							style: const TextStyle(
								color: Color(0xFFF5F6F8),
								fontSize: 12,
								fontWeight: FontWeight.w700,
							),
						),
					),
					const SizedBox(width: 8),
					GestureDetector(
						onTap: _permissionsController.requestPermissions,
						child: const Text(
							'RETRY',
							style: TextStyle(
								color: Color(0xFFF7B21A),
								fontSize: 12,
								fontWeight: FontWeight.w900,
							),
						),
					),
				],
			),
		);
	}

	Widget _filterBar() {
		return Container(
			margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
			height: 56,
			decoration: const BoxDecoration(
				color: Color(0xFF171A20),
				border: Border(left: BorderSide(color: Color(0xFFF7B21A), width: 3)),
			),
			child: Row(
				children: [
					const SizedBox(width: 16),
					const Icon(Icons.filter_list, color: Color(0xFF737885), size: 20),
					const SizedBox(width: 12),
					Expanded(
						child: TextField(
							controller: _filterController,
							onChanged: (v) => setState(() => _filterText = v),
							style: const TextStyle(
								color: Color(0xFFD5D8DE),
								fontSize: 13,
								fontWeight: FontWeight.w700,
								letterSpacing: 1.0,
							),
							decoration: const InputDecoration(
								hintText: 'FILTER BY NODE OR PRIORITY...',
								hintStyle: TextStyle(
									color: Color(0xFF5D616A),
									fontSize: 13,
									fontWeight: FontWeight.w700,
									letterSpacing: 1.0,
								),
								border: InputBorder.none,
								isDense: true,
							),
						),
					),
				],
			),
		);
	}

	Widget _statusLinkCard(ChatState state) {
		final String deviceLabel = _displayNameForPeer(state.session.peerId ?? 'ACTIVE_DEVICE', state);
		final bool linked = state.connectionState.toLowerCase() == 'connected';
		final String stateLabel = linked ? 'ACTIVE' : 'STANDBY';
		final String linkLabel = linked ? 'LINK ESTABLISHED' : 'LINK PENDING';

		return Container(
			margin: const EdgeInsets.fromLTRB(16, 18, 16, 0),
			height: 80,
			decoration: const BoxDecoration(
				color: Color(0xFF171A20),
				border: Border(left: BorderSide(color: Color(0xFFF7B21A), width: 3)),
			),
			child: Padding(
				padding: const EdgeInsets.symmetric(horizontal: 14),
				child: Row(
					children: [
						const Icon(Icons.wifi_tethering, color: Color(0xFFF7B21A), size: 18),
						const SizedBox(width: 10),
						Expanded(
							child: RichText(
								maxLines: 1,
								overflow: TextOverflow.ellipsis,
								text: TextSpan(
									children: [
										TextSpan(
											text: '${deviceLabel.toUpperCase()} - ',
											style: const TextStyle(
												color: Color(0xFFEFF1F5),
												fontSize: 17,
												fontWeight: FontWeight.w900,
												letterSpacing: 0.3,
											),
										),
										TextSpan(
											text: stateLabel,
											style: const TextStyle(
												color: Color(0xFFF7B21A),
												fontSize: 17,
												fontWeight: FontWeight.w900,
												letterSpacing: 1.0,
											),
										),
									],
								),
							),
						),
						const SizedBox(width: 10),
						Container(
							width: 14,
							height: 14,
							decoration: BoxDecoration(
								color: linked ? const Color(0xFFB68118) : const Color(0xFF50545E),
								borderRadius: BorderRadius.circular(7),
							),
						),
						const SizedBox(width: 8),
						Flexible(
							child: Text(
								linkLabel,
								style: const TextStyle(
									color: Color(0xFF7E838D),
									fontSize: 11,
									fontWeight: FontWeight.w800,
									letterSpacing: 0.8,
								),
								maxLines: 1,
								overflow: TextOverflow.ellipsis,
							),
						),
					],
				),
			),
		);
	}

	Widget _conversationsList(ChatState state, Map<String, List<ChatMessageDto>> byPeer) {
		final List<MapEntry<String, List<ChatMessageDto>>> entries = byPeer.entries.toList();
		entries.sort((a, b) {
			final int aTime = a.value.isNotEmpty ? a.value.last.createdAtMs : 0;
			final int bTime = b.value.isNotEmpty ? b.value.last.createdAtMs : 0;
			return bTime.compareTo(aTime);
		});

		return ListView(
			padding: const EdgeInsets.fromLTRB(0, 20, 0, 120),
			children: [
				const Padding(
					padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
					child: Text(
						'ACTIVE CONVERSATIONS',
						style: TextStyle(
							color: Color(0xFF737885),
							fontSize: 12,
							fontWeight: FontWeight.w800,
							letterSpacing: 1.5,
						),
					),
				),
				const Divider(color: Color(0xFF1E2128), thickness: 1, height: 1),
				...entries.map((entry) {
					final String peerId = entry.key;
					final List<ChatMessageDto> msgs = entry.value;
					final ChatMessageDto? lastMsg = msgs.isNotEmpty ? msgs.last : null;
					final bool isActive = state.session.peerId == peerId && state.session.connected;
					final String? badge = isActive ? 'ENCRYPTED' : null;
					final String signalLabel = _signalLabel(state.connectionState);
					return _conversationCard(
						title: _displayNameForPeer(peerId, state),
						badge: badge,
						lastMessage: _messagePreview(lastMsg),
						lastMessageTimeMs: lastMsg?.createdAtMs,
						signalStrength: signalLabel,
					);
				}),
			],
		);
	}

	String? _messagePreview(ChatMessageDto? msg) {
		if (msg == null) return null;
		final QuickStatusPayload? status = QuickStatusPayload.fromMessageContent(msg.content);
		if (status == null) {
			return msg.content;
		}
		final String state = status.isExpired ? 'STANDBY' : 'ACTIVE ${status.remainingLabel}';
		return 'STATUS ${status.statusLabel} • ${status.deviceName} • $state';
	}

	String _displayNameForPeer(String peerId, ChatState state) {
		if (peerId == 'LOCAL_USER') {
			return 'THIS DEVICE';
		}
		if (state.session.peerId != null && peerId == state.session.peerId) {
			return state.session.peerName?.trim().isNotEmpty == true
				? state.session.peerName!
				: (state.session.peerId ?? peerId);
		}
		if (state.session.peerName != null && peerId == state.session.peerName) {
			return state.session.peerName!;
		}
		if (peerId.trim().isEmpty || peerId == 'UNKNOWN_DEVICE') {
			return 'UNKNOWN DEVICE';
		}
		return peerId;
	}

	Widget _conversationCard({
		required String title,
		String? badge,
		String? lastMessage,
		int? lastMessageTimeMs,
		String? signalStrength,
	}) {
		final String timeLabel = lastMessageTimeMs != null ? _formatTime(lastMessageTimeMs) : '';
		final String preview = lastMessage != null ? lastMessage.toUpperCase() : '';

		return Column(
			children: [
				IntrinsicHeight(
					child: Row(
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							Container(width: 4, color: _amber),
							Expanded(
								child: Padding(
									padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											Row(
												children: [
													Expanded(
														child: Text(
															title.toUpperCase(),
															style: const TextStyle(
																color: Color(0xFFEFF1F5),
																fontSize: 15,
																fontWeight: FontWeight.w900,
																letterSpacing: 0.5,
															),
															maxLines: 1,
															overflow: TextOverflow.ellipsis,
														),
													),
													if (badge != null) ...[
														const SizedBox(width: 8),
														Container(
															padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
															color: const Color(0xFF1F2229),
															child: Row(
																mainAxisSize: MainAxisSize.min,
																children: [
																	const Icon(Icons.shield_outlined, color: Color(0xFFF7B21A), size: 11),
																	const SizedBox(width: 4),
																	Text(
																		badge,
																		style: const TextStyle(
																			color: Color(0xFFF7B21A),
																			fontSize: 10,
																			fontWeight: FontWeight.w800,
																			letterSpacing: 0.8,
																		),
																	),
																],
															),
														),
													],
													const SizedBox(width: 8),
													Text(
														timeLabel,
														style: const TextStyle(
															color: Color(0xFF737885),
															fontSize: 12,
															fontWeight: FontWeight.w700,
														),
													),
												],
											),
											if (preview.isNotEmpty) ...[
												const SizedBox(height: 8),
												Text(
													preview.length > 80 ? '${preview.substring(0, 80)}...' : preview,
													style: const TextStyle(
														color: Color(0xFF9CA0AA),
														fontSize: 13,
														height: 1.4,
													),
													maxLines: 2,
													overflow: TextOverflow.ellipsis,
												),
											],
											if (signalStrength != null) ...[
												const SizedBox(height: 8),
												Row(
													children: [
														const Icon(Icons.signal_cellular_alt, color: Color(0xFF737885), size: 14),
														const SizedBox(width: 5),
														Text(
															'STRENGTH: $signalStrength',
															style: const TextStyle(
																color: Color(0xFF737885),
																fontSize: 11,
																fontWeight: FontWeight.w700,
																letterSpacing: 0.8,
															),
														),
													],
												),
											],
										],
									),
								),
							),
						],
					),
				),
				const Divider(color: Color(0xFF1E2128), thickness: 1, height: 1),
			],
		);
	}

	Widget _emptyState() {
		return Center(
			child: Column(
				mainAxisAlignment: MainAxisAlignment.center,
				children: const [
					Icon(
						Icons.forum_outlined,
						color: Color(0xFF2A2E3A),
						size: 80,
					),
					SizedBox(height: 20),
					Text(
						'NO MESSAGES FOUND',
						style: TextStyle(
							color: Color(0xFF4A4F5C),
							fontSize: 13,
							fontWeight: FontWeight.w800,
							letterSpacing: 2.0,
						),
					),
				],
			),
		);
	}

	Widget _fab(BuildContext context) {
		return GestureDetector(
			onTap: () => Navigator.of(context).pushNamed(
				AppRoutes.chat,
				arguments: const ChatRouteArgs(forceStandby: false),
			),
			child: Container(
				width: 64,
				height: 64,
				color: _amber,
				child: const Icon(Icons.add_comment_outlined, color: Colors.black, size: 28),
			),
		);
	}

	String _signalLabel(String connectionState) {
		switch (connectionState.toLowerCase()) {
			case 'connected':
				return 'OPTIMAL';
			case 'connecting':
				return 'STABLE';
			default:
				return 'WEAK';
		}
	}

	String _formatTime(int createdAtMs) {
		final DateTime dt = DateTime.fromMillisecondsSinceEpoch(createdAtMs);
		final DateTime now = DateTime.now();
		if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
			final String hh = dt.hour.toString().padLeft(2, '0');
			final String mm = dt.minute.toString().padLeft(2, '0');
			return '$hh:$mm UTC';
		}
		return 'YESTERDAY';
	}

	Widget _bottomNav(BuildContext context) {
		return Container(
			height: 86,
			color: const Color(0xFF090B10),
			padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
			child: Row(
				mainAxisAlignment: MainAxisAlignment.spaceBetween,
				children: [
					Expanded(
						child: _NavItem(
							icon: Icons.grid_view,
							label: 'DASHBOARD',
							active: false,
							onTap: () => Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard),
						),
					),
					const Expanded(child: _NavItem(icon: Icons.chat, label: 'CHAT', active: true)),
					Expanded(
						child: _NavItem(
							icon: Icons.flash_on,
							label: 'POWER',
							active: false,
							onTap: () => Navigator.of(context).pushReplacementNamed(AppRoutes.power),
						),
					),
					Expanded(
						child: _NavItem(
							icon: Icons.warning,
							label: 'SOS',
							active: false,
							onTap: () => Navigator.of(context).pushReplacementNamed(AppRoutes.sos),
						),
					),
				],
			),
		);
	}
}

class _NavItem extends StatelessWidget {
	const _NavItem({
		required this.icon,
		required this.label,
		required this.active,
		this.onTap,
	});

	final IconData icon;
	final String label;
	final bool active;
	final VoidCallback? onTap;

	@override
	Widget build(BuildContext context) {
		return GestureDetector(
			onTap: onTap,
			behavior: HitTestBehavior.opaque,
			child: Container(
				padding: const EdgeInsets.symmetric(vertical: 2),
				decoration: BoxDecoration(
					color: active ? const Color(0xFFF7B21A) : Colors.transparent,
					borderRadius: BorderRadius.circular(4),
				),
				child: Column(
					mainAxisAlignment: MainAxisAlignment.center,
					children: [
						Icon(icon, color: active ? Colors.black : const Color(0xFF737885), size: 21),
						const SizedBox(height: 4),
						Text(
							label,
							style: TextStyle(
								color: active ? Colors.black : const Color(0xFF737885),
								fontSize: 11,
								fontWeight: FontWeight.w800,
								letterSpacing: 0.7,
							),
							maxLines: 1,
							overflow: TextOverflow.ellipsis,
						),
					],
				),
			),
		);
	}
}
