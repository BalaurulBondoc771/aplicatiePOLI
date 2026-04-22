import 'package:flutter/material.dart';
import 'app_routes.dart';
import 'chat/chat_controller.dart';
import 'chat/chat_message_dto.dart';
import 'chat/chat_state.dart';
import 'chat/chat_session_dto.dart';
import 'location/location_dto.dart';
import 'permissions/permissions_controller.dart';
import 'permissions/permissions_state.dart';
import 'services/location_channel_service.dart';

class ChatPage extends StatefulWidget {
	const ChatPage({super.key, this.initialArgs});

	final ChatRouteArgs? initialArgs;

	@override
	State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
	final ChatController _controller = ChatController();
	final PermissionsController _permissionsController = PermissionsController(includeMicrophone: true);
	final TextEditingController _draftController = TextEditingController();
	bool _initialized = false;
	LocationDto? _attachedLocation;
	String? _attachCoordsLabel;

	static const Color _bg = Color(0xFF07090D);
	static const Color _panel = Color(0xFF171A20);
	static const Color _panelSoft = Color(0xFF24272E);
	static const Color _amber = Color(0xFFF7B21A);

	@override
	void didChangeDependencies() {
		super.didChangeDependencies();
		if (_initialized) return;
		_initialized = true;
		final routeArgs = widget.initialArgs ?? AppRoutes.chatArgsOf(ModalRoute.of(context)?.settings.arguments);
		_controller.init(routeArgs);
		_permissionsController.init();
	}

	@override
	void dispose() {
		_draftController.dispose();
		_permissionsController.dispose();
		_controller.dispose();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		return StreamBuilder<PermissionsState>(
			stream: _permissionsController.stateStream,
			initialData: _permissionsController.state,
			builder: (context, permissionSnapshot) {
				final permissionState = permissionSnapshot.data ?? _permissionsController.state;
				return StreamBuilder<ChatState>(
					stream: _controller.stateStream,
					initialData: _controller.state,
					builder: (context, snapshot) {
				final ChatState viewState = snapshot.data ?? _controller.state;
				final ChatSessionDto session = viewState.session;
				if (_draftController.text != viewState.draft) {
					_draftController.value = TextEditingValue(
						text: viewState.draft,
						selection: TextSelection.collapsed(offset: viewState.draft.length),
					);
				}

				return Scaffold(
					backgroundColor: _bg,
					body: SafeArea(
						bottom: true,
						child: Column(
							children: [
								_topBar(viewState),
								if (!permissionState.canUseMeshActions || !permissionState.canUseLocationActions)
									Container(
										width: double.infinity,
										padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
										color: const Color(0x33EF242B),
										child: Row(
											children: [
												Expanded(
													child: Text(
														permissionState.toBannerMessage(includeMicrophone: true),
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
									),
								Expanded(
									child: SingleChildScrollView(
										physics: const BouncingScrollPhysics(),
										child: Padding(
											padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
											child: Column(
												crossAxisAlignment: CrossAxisAlignment.start,
												children: [
													_meshCard(viewState),
													if (viewState.lastError != null || session.errorCode != null)
														Padding(
															padding: const EdgeInsets.only(top: 10),
															child: Text(
																'CHAT MODE: ${session.errorCode ?? viewState.lastError}',
																style: const TextStyle(
																	color: Color(0xFFFFC266),
																	fontSize: 12,
																	fontWeight: FontWeight.w700,
																	letterSpacing: 0.6,
																),
															),
														),
													const SizedBox(height: 20),
													..._messageTimeline(viewState),
													const SizedBox(height: 12),
													Row(
														children: [
															const Icon(Icons.settings_input_antenna, color: Color(0xFFF7B21A), size: 18),
															const SizedBox(width: 6),
															Expanded(
																child: Text(
																	viewState.connectionState == 'connected' ? 'MESH RANGE: OPTIMAL' : 'MESH RANGE: DISCONNECTED',
																	textAlign: TextAlign.center,
																	style: const TextStyle(
																		color: Color(0xFFF7B21A),
																		fontSize: 20,
																		fontWeight: FontWeight.w800,
																		letterSpacing: 0.3,
																		height: 1,
																	),
																	maxLines: 1,
																	overflow: TextOverflow.ellipsis,
																),
															),
															const SizedBox(width: 6),
															Icon(
																viewState.connectionState == 'connected' ? Icons.done_all : Icons.signal_cellular_connected_no_internet_4_bar,
																color: const Color(0xFFF7B21A),
																size: 18,
															),
														],
													),
													const SizedBox(height: 22),
													_dividerText(),
													const SizedBox(height: 22),
													const Text(
														'BASE COMMAND  11:15',
														style: TextStyle(
															color: Color(0xFF6D727D),
															fontSize: 13,
															fontWeight: FontWeight.w800,
															letterSpacing: 1.1,
														),
													),
													const SizedBox(height: 10),
													Container(
														width: double.infinity,
														padding: const EdgeInsets.fromLTRB(26, 22, 22, 24),
														color: _panelSoft,
														child: const Text(
															'System update required for relay handoff.\nRoute through backup telemetry node.',
															style: TextStyle(
																color: Color(0xFFD5D8DE),
																fontSize: 22,
																height: 1.45,
																fontStyle: FontStyle.italic,
															),
														),
													),
												],
											),
										),
									),
								),
								_composer(viewState, permissionState),
								_bottomNav(context),
							],
						),
					),
				);
					},
				);
			},
		);
	}

	Widget _topBar(ChatState state) {
		final String meshStatus = state.connectionState.toUpperCase();
		return Container(
			height: 78,
			color: const Color(0xFF0F1218),
			padding: const EdgeInsets.symmetric(horizontal: 12),
			child: Row(
				children: [
					Icon(Icons.navigation, color: _amber, size: 20),
					const SizedBox(width: 8),
					const Expanded(
						child: Text(
							'BLACKOUT LINK',
							style: TextStyle(
								color: Color(0xFFF7B21A),
								fontSize: 28,
								fontWeight: FontWeight.w900,
								letterSpacing: 0.1,
								height: 1,
							),
							maxLines: 1,
							overflow: TextOverflow.ellipsis,
						),
					),
					const Spacer(),
					Column(
						mainAxisAlignment: MainAxisAlignment.center,
						crossAxisAlignment: CrossAxisAlignment.end,
						children: [
							const Text(
								'MESH STATUS',
								style: TextStyle(
									color: Color(0xFF6E7380),
									fontSize: 12,
									fontWeight: FontWeight.w700,
									letterSpacing: 1,
								),
							),
							const SizedBox(height: 4),
							Text(
								meshStatus,
								style: TextStyle(
									color: Color(0xFFF7B21A),
									fontSize: 13,
									fontWeight: FontWeight.w800,
									letterSpacing: 0.5,
								),
								maxLines: 1,
								overflow: TextOverflow.ellipsis,
							),
						],
					),
					const SizedBox(width: 14),
					const Icon(Icons.settings, color: Color(0xFFA8ADB8), size: 26),
				],
			),
		);
	}

	Widget _meshCard(ChatState state) {
		final ChatSessionDto session = state.session;
		final String nodeLabel = session.peerName ?? session.peerId ?? 'STANDBY / NO PEERS';
		final String latencyLabel = '${state.latencyMs}MS';
		final String sessionLabel = state.sessionState.toUpperCase();
		return Container(
			width: double.infinity,
			constraints: const BoxConstraints(minHeight: 128),
			color: _panel,
			child: Row(
				children: [
					Container(width: 7, color: _amber),
					Expanded(
						child: Padding(
							padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
							child: Row(
								children: [
									Container(
										width: 64,
										height: 64,
										color: const Color(0xFF2A2D35),
										child: const Icon(Icons.hub_outlined, color: Color(0xFFF7B21A), size: 38),
									),
									const SizedBox(width: 14),
									Expanded(
										child: Column(
											crossAxisAlignment: CrossAxisAlignment.start,
											mainAxisAlignment: MainAxisAlignment.center,
											children: [
												const Text(
													'CONNECTED VIA',
													style: TextStyle(
														color: Color(0xFF848A95),
														fontSize: 12,
														fontWeight: FontWeight.w700,
														letterSpacing: 1.5,
													),
												),
												const SizedBox(height: 4),
												Text(
													'BLUETOOTH MESH NODE\n$nodeLabel',
													style: TextStyle(
														color: Color(0xFFD8DBE2),
														fontSize: 17,
														fontWeight: FontWeight.w800,
														height: 1.2,
													),
													maxLines: 2,
													overflow: TextOverflow.ellipsis,
												),
											],
										),
									),
									Column(
										mainAxisAlignment: MainAxisAlignment.center,
										crossAxisAlignment: CrossAxisAlignment.end,
										children: [
											const Text(
												'LATENCY',
												style: TextStyle(
													color: Color(0xFF848A95),
													fontSize: 12,
													fontWeight: FontWeight.w700,
													letterSpacing: 1.2,
												),
											),
											const SizedBox(height: 6),
											Text(
												latencyLabel,
												style: TextStyle(
													color: Color(0xFFF7B21A),
													fontSize: 18,
													fontWeight: FontWeight.w800,
													height: 1,
												),
											),
											const SizedBox(height: 4),
											Text(
												sessionLabel,
												style: const TextStyle(
													color: Color(0xFF848A95),
													fontSize: 11,
													fontWeight: FontWeight.w700,
													letterSpacing: 1.0,
												),
											),
										],
									),
								],
							),
						),
					),
				],
			),
		);
	}

	List<Widget> _messageTimeline(ChatState viewState) {
		if (viewState.messages.isEmpty) {
			return [
				const Text(
					'NO MESSAGES YET',
					style: TextStyle(
						color: Color(0xFF6E7380),
						fontSize: 13,
						fontWeight: FontWeight.w800,
						letterSpacing: 1.2,
					),
				),
				const SizedBox(height: 10),
				Container(
					width: double.infinity,
					padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
					color: _panelSoft,
					child: const Text(
						'Offline session ready. Send a message to start the local queue.',
						style: TextStyle(
							color: Color(0xFFD7DAE0),
							fontSize: 24,
							height: 1.45,
						),
					),
				),
			];
		}

		final List<Widget> widgets = <Widget>[];
		for (final ChatMessageDto message in viewState.messages) {
			widgets.add(
				Align(
					alignment: message.outgoing ? Alignment.centerRight : Alignment.centerLeft,
					child: Text(
						'${_formatTime(message.createdAtMs)}  ${message.outgoing ? 'YOU' : 'PEER'}',
						style: TextStyle(
							color: message.outgoing ? _amber : const Color(0xFF6E7380),
							fontSize: 13,
							fontWeight: FontWeight.w800,
							letterSpacing: 1.1,
						),
					),
				),
			);
			widgets.add(const SizedBox(height: 10));
			widgets.add(
				Container(
					width: double.infinity,
					padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
					color: message.outgoing ? _amber : _panelSoft,
					child: Text(
						message.content,
						style: TextStyle(
							color: message.outgoing ? Colors.black : const Color(0xFFD7DAE0),
							fontSize: 24,
							height: 1.45,
							fontWeight: message.outgoing ? FontWeight.w700 : FontWeight.w500,
						),
					),
				),
			);
			widgets.add(const SizedBox(height: 8));
			widgets.add(
				Align(
					alignment: message.outgoing ? Alignment.centerRight : Alignment.centerLeft,
					child: Row(
						mainAxisSize: MainAxisSize.min,
						children: [
							Text(
								'STATUS: ${message.status}',
								style: TextStyle(
									color: _statusColor(message.status),
									fontSize: 12,
									fontWeight: FontWeight.w800,
									letterSpacing: 1.0,
								),
							),
							if (message.outgoing && message.status.toUpperCase() == 'FAILED') ...[
								const SizedBox(width: 12),
								GestureDetector(
									onTap: () => _controller.retryFailed(message.id),
									child: const Text(
										'RETRY',
										style: TextStyle(
											color: Color(0xFFF7B21A),
											fontSize: 12,
											fontWeight: FontWeight.w900,
											letterSpacing: 1.1,
										),
									),
								),
							],
						],
					),
				),
			);
			widgets.add(const SizedBox(height: 18));
		}

		return widgets;
	}

	Color _statusColor(String status) {
		switch (status.toUpperCase()) {
			case 'SENT':
				return const Color(0xFF00DF86);
			case 'FAILED':
				return const Color(0xFFFF4C65);
			default:
				return const Color(0xFFF7B21A);
		}
	}

	String _formatTime(int createdAtMs) {
		final DateTime dt = DateTime.fromMillisecondsSinceEpoch(createdAtMs);
		final String hh = dt.hour.toString().padLeft(2, '0');
		final String mm = dt.minute.toString().padLeft(2, '0');
		return '$hh:$mm';
	}

	Widget _dividerText() {
		return Row(
			children: const [
				Expanded(child: Divider(color: Color(0xFF343942), thickness: 1)),
				SizedBox(width: 14),
				Flexible(
					child: Text(
						'END OF ENCRYPTED SESSION',
						textAlign: TextAlign.center,
						style: TextStyle(
							color: Color(0xFF5D626D),
							fontSize: 12,
							fontWeight: FontWeight.w800,
							letterSpacing: 1.2,
						),
						maxLines: 1,
						overflow: TextOverflow.ellipsis,
					),
				),
				SizedBox(width: 14),
				Expanded(child: Divider(color: Color(0xFF343942), thickness: 1)),
			],
		);
	}

	Widget _composer(ChatState state, PermissionsState permissions) {
		return Container(
			constraints: const BoxConstraints(minHeight: 126),
			color: const Color(0xFF1A1D24),
			padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
			child: Column(
				mainAxisSize: MainAxisSize.min,
				children: [
					if (_attachCoordsLabel != null)
						Padding(
							padding: const EdgeInsets.only(bottom: 10),
							child: Align(
								alignment: Alignment.centerLeft,
								child: Text(
									_attachCoordsLabel!,
									style: const TextStyle(
										color: Color(0xFFF7B21A),
										fontSize: 11,
										fontWeight: FontWeight.w700,
										letterSpacing: 0.8,
									),
									maxLines: 2,
									overflow: TextOverflow.ellipsis,
								),
							),
						),
					Row(
						children: [
							Expanded(
								child: Wrap(
									spacing: 14,
									runSpacing: 2,
									crossAxisAlignment: WrapCrossAlignment.center,
									children: [
										GestureDetector(
											onTap: permissions.canUseLocationActions ? _attachCurrentCoords : _permissionsController.requestPermissions,
											child: const Row(
												mainAxisSize: MainAxisSize.min,
												children: [
													Icon(Icons.place_outlined, color: Color(0xFFA3A8B2), size: 18),
													SizedBox(width: 6),
													Text(
														'ATTACH\nCOORDS',
														style: TextStyle(color: Color(0xFFA3A8B2), fontSize: 10, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: 1),
													),
												],
											),
										),
										const Row(
											mainAxisSize: MainAxisSize.min,
											children: [
												Icon(Icons.mic_none, color: Color(0xFFA3A8B2), size: 18),
												SizedBox(width: 6),
												Text(
													'VOICE\nBURST',
													style: TextStyle(color: Color(0xFFA3A8B2), fontSize: 10, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: 1),
												),
											],
										),
									],
								),
							),
							const SizedBox(width: 8),
							Text(
								'${240 - state.draft.length.clamp(0, 240)} CHRS\nREMAINING',
								textAlign: TextAlign.right,
								style: const TextStyle(color: Color(0xFF5E646F), fontSize: 10, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: 1),
							),
						],
					),
					const SizedBox(height: 12),
					SizedBox(
						height: 56,
						child: Row(
							children: [
								Expanded(
									child: Container(
										color: const Color(0xFF31343B),
										alignment: Alignment.centerLeft,
										padding: const EdgeInsets.symmetric(horizontal: 16),
										child: TextField(
											controller: _draftController,
											onChanged: _controller.updateDraft,
											maxLines: 2,
											minLines: 1,
											style: const TextStyle(
												color: Color(0xFFE7EAF0),
												fontSize: 20,
												fontWeight: FontWeight.w700,
												height: 1.2,
											),
											decoration: const InputDecoration(
												hintText: 'ENTER MESSAGE...',
												hintStyle: TextStyle(
													color: Color(0xFF5D616A),
													fontSize: 20,
													fontWeight: FontWeight.w800,
												),
												border: InputBorder.none,
											),
										),
									),
								),
								const SizedBox(width: 8),
								Flexible(
									flex: 0,
									child: GestureDetector(
									onTap: state.sending
										? null
										: (permissions.canUseMeshActions ? _sendFromComposer : _permissionsController.requestPermissions),
									child: Container(
										constraints: const BoxConstraints(minWidth: 96, maxWidth: 132),
										color: state.sending ? const Color(0xFF92733A) : _amber,
										alignment: Alignment.center,
										child: Text(
											state.sending ? 'SENDING...' : 'SEND  >',
											style: const TextStyle(
												color: Colors.black,
												fontSize: 18,
												fontWeight: FontWeight.w900,
												letterSpacing: 1.1,
											),
											maxLines: 1,
											overflow: TextOverflow.ellipsis,
										),
									),
								),
								),
							],
						),
					),
				],
			),
		);
	}

	Future<void> _attachCurrentCoords() async {
		try {
			final LocationDto current = await LocationChannelService.getCurrentLocation();
			if (!mounted) return;
			setState(() {
				_attachedLocation = current;
				_attachCoordsLabel =
					current.isFallback
						? 'COORDS ATTACHED (FALLBACK${current.isStale ? ', STALE' : ''}): ${current.toInlineLabel()}'
						: 'COORDS ATTACHED (LIVE${current.isStale ? ', STALE' : ''}): ${current.toInlineLabel()}';
			});
		} catch (_) {
			try {
				final LocationDto fallback = await LocationChannelService.getLastKnownLocation();
				if (!mounted) return;
				setState(() {
					_attachedLocation = fallback;
					_attachCoordsLabel = 'COORDS ATTACHED (LAST KNOWN${fallback.isStale ? ', STALE' : ''}): ${fallback.toInlineLabel()}';
				});
			} catch (e) {
				if (!mounted) return;
				setState(() {
					_attachedLocation = null;
					_attachCoordsLabel = 'COORDS UNAVAILABLE: $e';
				});
			}
		}
	}

	Future<void> _sendFromComposer() async {
		final String draft = _controller.state.draft;
		if (_attachedLocation == null) {
			await _controller.sendText(draft);
			return;
		}

		final loc = _attachedLocation!;
		final String sourceTag = loc.isFallback ? 'LAST_KNOWN' : 'LIVE';
		final String staleTag = loc.isStale ? 'STALE' : 'FRESH';
		final String enriched =
			'$draft\n\n[COORDS:$sourceTag:$staleTag ${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)} +/-${loc.accuracyMeters.toStringAsFixed(0)}m ts=${loc.timestampMs}]';

		await _controller.sendText(enriched);
		if (!mounted) return;
		setState(() {
			_attachedLocation = null;
			_attachCoordsLabel = null;
		});
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
