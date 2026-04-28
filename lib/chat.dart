import 'dart:async';

import 'package:flutter/material.dart';
import 'app_routes.dart';
import 'chat/chat_controller.dart';
import 'chat/chat_message_dto.dart';
import 'chat/chat_state.dart';
import 'permissions/permissions_controller.dart';
import 'permissions/permissions_state.dart';
import 'quick_status_models.dart';
import 'services/mesh_channel_service.dart';

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
	final TextEditingController _messageController = TextEditingController();
	Timer? _statusTickTimer;
	bool _initialized = false;
	String _filterText = '';
	String? _activePeerId;
	String? _activePeerName;

	static const Color _bg = Color(0xFF07090D);
	static const Color _amber = Color(0xFFF7B21A);

	@override
	void didChangeDependencies() {
		super.didChangeDependencies();
		if (_initialized) return;
		_initialized = true;
		final routeArgs = widget.initialArgs ?? AppRoutes.chatArgsOf(ModalRoute.of(context)?.settings.arguments);
		_activePeerId = routeArgs?.peerId;
		_activePeerName = routeArgs?.peerName;
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
		_messageController.dispose();
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
						final String? currentPeerId = _activePeerId;
						final String? currentPeerName = _activePeerName;
						final bool inConversation = currentPeerId?.trim().isNotEmpty == true;

						// Group only actual chat messages; connection status has its own card.
						final Map<String, List<ChatMessageDto>> byPeer = {};
						for (final ChatMessageDto msg in viewState.messages) {
							final String? key = _peerKeyForMessage(msg);
							if (key == null) continue;
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
												_topBar(
													state: viewState,
													inConversation: inConversation,
													activePeerId: currentPeerId,
													activePeerName: currentPeerName,
												),
												if (!permState.canUseMeshActions || !permState.canUseLocationActions)
													_permissionBanner(permState),
												if (!inConversation) ...[
													_filterBar(),
													_statusLinkCard(viewState),
													Expanded(
														child: hasConversations
															? _conversationsList(viewState, filtered)
															: _emptyState(),
													),
												] else ...[
													Expanded(
														child: _conversationThread(
															state: viewState,
															activePeerId: currentPeerId!,
														),
													),
													_messageComposer(viewState, currentPeerId),
												],
												_bottomNav(context),
											],
										),
										if (!inConversation)
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

	Widget _topBar({
		required ChatState state,
		required bool inConversation,
		required String? activePeerId,
		required String? activePeerName,
	}) {
		final String title = inConversation
			? _displayTitleForActivePeer(activePeerId, activePeerName, state)
			: 'BLACKOUT LINK';
		return Container(
			height: 78,
			color: const Color(0xFF0F1218),
			padding: const EdgeInsets.symmetric(horizontal: 16),
			child: Row(
				children: [
					GestureDetector(
						onTap: inConversation
							? () {
								setState(() {
									_activePeerId = null;
									_activePeerName = null;
								});
							}
							: null,
						child: Icon(
							inConversation ? Icons.arrow_back : Icons.navigation,
							color: _amber,
							size: 24,
						),
					),
					const SizedBox(width: 8),
					Expanded(
						child: Text(
							title.toUpperCase(),
							maxLines: 1,
							overflow: TextOverflow.ellipsis,
							style: const TextStyle(
								color: Color(0xFFF7B21A),
								fontSize: 24,
								fontWeight: FontWeight.w900,
								letterSpacing: 0.5,
								height: 1,
							),
						),
					),
					const SizedBox(width: 8),
					if (!inConversation) ...[
						const Icon(Icons.search, color: Color(0xFFA8ADB8), size: 26),
						const SizedBox(width: 12),
						const Icon(Icons.settings, color: Color(0xFFA8ADB8), size: 26),
					] else ...[
						const Icon(Icons.shield_outlined, color: Color(0xFFA8ADB8), size: 22),
					],
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
					final bool isActive = _samePeerIdentifier(state.session.peerId, peerId) && state.session.connected;
					final String? badge = isActive ? 'ENCRYPTED' : null;
					final String signalLabel = _signalLabel(state.connectionState);
					final String displayName = _displayNameForPeer(peerId, state);
					return GestureDetector(
						onTap: () => _openConversation(peerId: peerId, peerName: displayName),
						behavior: HitTestBehavior.opaque,
						child: _conversationCard(
							title: displayName,
							badge: badge,
							lastMessage: _messagePreview(lastMsg),
							lastMessageTimeMs: lastMsg?.createdAtMs,
							signalStrength: signalLabel,
						),
					);
				}),
			],
		);
	}

	String _displayTitleForActivePeer(String? peerId, String? peerName, ChatState state) {
		if (peerName != null && peerName.trim().isNotEmpty) {
			return peerName;
		}
		if (peerId == null || peerId.trim().isEmpty) {
			return 'UNKNOWN DEVICE';
		}
		return _displayNameForPeer(peerId, state);
	}

	List<ChatMessageDto> _messagesForPeer({
		required List<ChatMessageDto> messages,
		required String activePeerId,
	}) {
		final String normalizedActivePeer = _normalizePeerKey(activePeerId);
		final List<ChatMessageDto> thread = <ChatMessageDto>[];
		for (final ChatMessageDto msg in messages) {
			final String? messagePeer = _peerKeyForMessage(msg);
			if (messagePeer != null && _normalizePeerKey(messagePeer) == normalizedActivePeer) {
				thread.add(msg);
			}
		}
		thread.sort((a, b) => a.createdAtMs.compareTo(b.createdAtMs));
		return thread;
	}

	Widget _conversationThread({
		required ChatState state,
		required String activePeerId,
	}) {
		final List<ChatMessageDto> messages = _messagesForPeer(
			messages: state.messages,
			activePeerId: activePeerId,
		);

		if (messages.isEmpty) {
			return const Center(
				child: Text(
					'NO MESSAGES YET',
					style: TextStyle(
						color: Color(0xFF4A4F5C),
						fontSize: 13,
						fontWeight: FontWeight.w800,
						letterSpacing: 2,
					),
				),
			);
		}

		return ListView.builder(
			padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
			itemCount: messages.length,
			itemBuilder: (context, index) {
				final ChatMessageDto msg = messages[index];
				return _messageBubble(msg);
			},
		);
	}

	Widget _messageBubble(ChatMessageDto msg) {
		final bool isErrorMessage = (msg.type ?? '').toUpperCase() == 'ERROR';
		final bool outgoing = msg.outgoing;
		final Alignment align = outgoing ? Alignment.centerRight : Alignment.centerLeft;
		final Color background = outgoing ? const Color(0xFFF0C65E) : const Color(0xFF1C2027);
		final Color textColor = outgoing ? Colors.black : const Color(0xFFE8EBF1);

		return Align(
			alignment: align,
			child: Padding(
				padding: const EdgeInsets.only(bottom: 10),
				child: ConstrainedBox(
					constraints: const BoxConstraints(maxWidth: 300),
					child: Container(
						decoration: BoxDecoration(
							color: background,
							border: Border(
								left: outgoing
									? BorderSide.none
									: const BorderSide(color: Color(0xFFF7B21A), width: 3),
							),
						),
						padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								Text(
									msg.content,
									style: TextStyle(
										color: textColor,
										fontSize: 16,
										height: 1.3,
										fontStyle: isErrorMessage ? FontStyle.italic : FontStyle.normal,
									),
								),
								const SizedBox(height: 8),
								Text(
									_formatCompactTime(msg.createdAtMs),
									style: TextStyle(
										color: outgoing ? Colors.black54 : const Color(0xFF8D939F),
										fontSize: 12,
										fontWeight: FontWeight.w700,
									),
								),
							],
						),
					),
				),
			),
		);
	}

	Widget _messageComposer(ChatState state, String? currentPeerId) {
		final bool hasPeer = currentPeerId != null && currentPeerId.trim().isNotEmpty;
		return Container(
			padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
			decoration: const BoxDecoration(
				color: Color(0xFF07090D),
				border: Border(
					top: BorderSide(color: Color(0xFF1E2128), width: 1),
				),
			),
			child: Row(
				children: [
					Expanded(
						child: Container(
							height: 56,
							padding: const EdgeInsets.symmetric(horizontal: 14),
							color: const Color(0xFF2A2C31),
							alignment: Alignment.center,
							child: TextField(
								controller: _messageController,
								onChanged: _controller.updateDraft,
								style: const TextStyle(
									color: Color(0xFFE8EBF1),
									fontSize: 15,
									fontWeight: FontWeight.w600,
								),
								decoration: const InputDecoration(
									hintText: 'ENTER MISSION INTEL...',
									hintStyle: TextStyle(
										color: Color(0xFF5D616A),
										fontSize: 15,
										fontWeight: FontWeight.w700,
										letterSpacing: 1.1,
									),
									border: InputBorder.none,
								),
								onSubmitted: (_) => _sendCurrentDraft(currentPeerId),
							),
						),
					),
					const SizedBox(width: 10),
					SizedBox(
						height: 56,
						width: 120,
						child: ElevatedButton(
							onPressed: (!hasPeer || state.sending) ? null : () => _sendCurrentDraft(currentPeerId),
							style: ElevatedButton.styleFrom(
								backgroundColor: _amber,
								foregroundColor: Colors.black,
								shape: const RoundedRectangleBorder(),
								elevation: 0,
							),
							child: const Text(
								'SEND',
								style: TextStyle(
									fontSize: 20,
									fontWeight: FontWeight.w900,
									letterSpacing: 1.1,
								),
							),
						),
					),
				],
			),
		);
	}

	Future<void> _sendCurrentDraft(String? currentPeerId) async {
		try {
			final String text = _messageController.text;
			if (text.trim().isEmpty) return;
			if (currentPeerId == null || currentPeerId.trim().isEmpty) return;

			if (!_samePeerIdentifier(_controller.state.session.peerId, currentPeerId)) {
				await _controller.openOfflineSession(
					peerId: currentPeerId,
					peerName: _activePeerName,
				);
			}

			await _controller.sendText(text);
			if (!mounted) return;
			_messageController.clear();
		} catch (_) {
			_controller.appendSendFailureNotice(peerId: currentPeerId);
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Mesajul nu a putut fi trimis.')),
			);
		}
	}

	Future<void> _openConversation({required String peerId, String? peerName}) async {
		if (peerId == 'LOCAL_USER' || peerId == 'UNKNOWN_DEVICE') {
			return;
		}

		final String normalizedPeerId = _normalizePeerKey(peerId);

		setState(() {
			_activePeerId = normalizedPeerId;
			_activePeerName = peerName;
		});

		await _controller.openOfflineSession(
			peerId: normalizedPeerId,
			peerName: peerName,
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
		if (_isMacLikePeerId(peerId)) {
			final String nodeLabel = _compactNodeLabel(peerId);
			final bool isCurrentSessionPeer = state.session.peerId == peerId;
			if (isCurrentSessionPeer && !state.session.connected) {
				return 'CONNECTION LOST - $nodeLabel';
			}
			if (!isCurrentSessionPeer) {
				return 'LAST SEEN - $nodeLabel';
			}
			return nodeLabel;
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

	String? _peerKeyForMessage(ChatMessageDto msg) {
		final String? raw = msg.peerId ?? (msg.outgoing ? null : msg.senderId);
		if (raw == null) return null;
		final String normalized = _normalizePeerKey(raw);
		if (normalized.isEmpty || normalized.toUpperCase() == 'LOCAL_USER') {
			return null;
		}
		return normalized;
	}

	String _normalizePeerKey(String value) {
		final String trimmed = value.trim();
		if (trimmed.isEmpty) return '';
		if (_isMacLikePeerId(trimmed)) {
			return trimmed.toUpperCase();
		}
		return trimmed;
	}

	bool _isMacLikePeerId(String value) {
		return RegExp(r'^[0-9A-F]{2}(?::[0-9A-F]{2}){5}$', caseSensitive: false)
			.hasMatch(value.trim());
	}

	String _compactNodeLabel(String macLikeId) {
		final String normalized = macLikeId.trim().toUpperCase();
		final List<String> parts = normalized.split(':');
		if (parts.isEmpty) {
			return 'NODE';
		}
		return 'NODE ${parts.last}';
	}

	bool _samePeerIdentifier(String? a, String? b) {
		String normalize(String? value) => (value ?? '').trim().toUpperCase();
		return normalize(a) == normalize(b);
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
			onTap: _openMeshDiscoveryDialog,
			child: Container(
				width: 64,
				height: 64,
				color: _amber,
				child: const Icon(Icons.add_comment_outlined, color: Colors.black, size: 28),
			),
		);
	}

	Future<void> _openMeshDiscoveryDialog() async {
		Map<String, dynamic> scanStart;
		try {
			scanStart = await MeshChannelService.startScan();
		} catch (e) {
			scanStart = <String, dynamic>{
				'ok': false,
				'error': 'scan_start_failed:$e',
			};
		}
		if (!mounted) return;

		final String? scanError = scanStart['reason'] != null
			? '${scanStart['reason']}'
			: (scanStart['error'] != null ? '${scanStart['error']}' : null);

		final Map<String, dynamic>? selectedPeer = await showDialog<Map<String, dynamic>>(
			context: context,
			barrierDismissible: true,
			builder: (dialogContext) {
				return Dialog(
					backgroundColor: const Color(0xFF17191D),
					insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
					child: SizedBox(
						width: double.infinity,
						child: Column(
							mainAxisSize: MainAxisSize.min,
							crossAxisAlignment: CrossAxisAlignment.stretch,
							children: [
								Container(
									color: const Color(0xFF2A2C31),
									padding: const EdgeInsets.fromLTRB(16, 16, 10, 16),
									child: Row(
										children: [
											const Expanded(
												child: Column(
													crossAxisAlignment: CrossAxisAlignment.start,
													children: [
														Text(
															'MESH DISCOVERY',
															style: TextStyle(
																color: Color(0xFFF7B21A),
																fontSize: 12,
																fontWeight: FontWeight.w800,
																letterSpacing: 2,
															),
														),
														SizedBox(height: 8),
														Text(
															'ESTABLISH LINK',
															style: TextStyle(
																color: Color(0xFFEFF1F5),
																fontSize: 22,
																fontWeight: FontWeight.w900,
															),
														),
													],
												),
											),
											IconButton(
												onPressed: () => Navigator.of(dialogContext).pop(),
												icon: const Icon(Icons.close, color: Color(0xFF80848F), size: 28),
											),
										],
									),
								),
								Container(
									color: const Color(0xFF17191D),
									padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											const Text(
												'Select a nearby Bluetooth node to bridge with the local mesh network.',
												style: TextStyle(
													color: Color(0xFFA8ADB8),
													fontSize: 15,
													height: 1.35,
												),
											),
											if (scanError != null) ...[
												const SizedBox(height: 10),
												Text(
													scanError.toUpperCase(),
													style: const TextStyle(
														color: Color(0xFFEF242B),
														fontSize: 11,
														fontWeight: FontWeight.w800,
														letterSpacing: 1,
													),
												),
											],
										],
									),
								),
								ConstrainedBox(
									constraints: const BoxConstraints(maxHeight: 360),
									child: StreamBuilder<Map<String, dynamic>>(
										stream: MeshChannelService.peersUpdates,
										builder: (context, snapshot) {
											final List<Map<String, dynamic>> peers = _parsePeers(snapshot.data);
											if (peers.isEmpty) {
												return const Padding(
													padding: EdgeInsets.fromLTRB(16, 18, 16, 16),
													child: Text(
														'No nearby nodes detected yet. Keep scan running and press refresh.',
														style: TextStyle(
															color: Color(0xFF8F939D),
															fontSize: 13,
														),
													),
												);
											}

											return ListView.separated(
												shrinkWrap: true,
												padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
												itemCount: peers.length,
												separatorBuilder: (context, index) => const SizedBox(height: 10),
												itemBuilder: (context, index) {
													final peer = peers[index];
													final name = '${peer['name'] ?? peer['id'] ?? 'UNKNOWN_NODE'}';
													final id = '${peer['id'] ?? ''}';
													final int rssi = (peer['rssi'] as num?)?.toInt() ?? -110;
													final String signal = rssi >= -65
														? 'STRONG SIGNAL'
														: (rssi >= -85 ? 'MEDIUM SIGNAL' : 'WEAK SIGNAL');
													final num? distance = peer['distanceMeters'] as num?;
													final String distanceLabel = distance == null
														? 'DISTANCE: CALCULATING'
														: 'DISTANCE: ~${distance.toStringAsFixed(0)}M';

													return InkWell(
														onTap: () => Navigator.of(dialogContext).pop(peer),
														child: Container(
															padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
															color: const Color(0xFF24272F),
															child: Row(
																children: [
																	Container(
																		width: 44,
																		height: 44,
																		alignment: Alignment.center,
																		color: const Color(0xFF2E3036),
																		child: const Icon(Icons.navigation, color: Color(0xFFF7B21A), size: 20),
																	),
																	const SizedBox(width: 12),
																	Expanded(
																		child: Column(
																			crossAxisAlignment: CrossAxisAlignment.start,
																			children: [
																				Text(
																					name.toUpperCase(),
																					maxLines: 1,
																					overflow: TextOverflow.ellipsis,
																					style: const TextStyle(
																						color: Color(0xFFEFF1F5),
																						fontSize: 16,
																						fontWeight: FontWeight.w900,
																					),
																				),
																				const SizedBox(height: 6),
																				Text(
																					distanceLabel,
																					maxLines: 1,
																					overflow: TextOverflow.ellipsis,
																					style: const TextStyle(
																						color: Color(0xFF8F939D),
																						fontSize: 12,
																						fontWeight: FontWeight.w700,
																						letterSpacing: 0.8,
																					),
																				),
																				if (id.isNotEmpty)
																					Text(
																						id,
																						maxLines: 1,
																						overflow: TextOverflow.ellipsis,
																						style: const TextStyle(
																							color: Color(0xFF5D616A),
																							fontSize: 10,
																						),
																					),
																	],
																),
															),
															Container(
																padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
																color: const Color(0xFF3B3324),
																child: Text(
																	signal,
																	style: const TextStyle(
																		color: Color(0xFFF7B21A),
																		fontSize: 11,
																		fontWeight: FontWeight.w800,
																		letterSpacing: 1,
																	),
																),
															),
														],
														),
													),
												);
												},
											);
										},
									),
								),
								Padding(
									padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
									child: SizedBox(
										height: 52,
										child: ElevatedButton(
											style: ElevatedButton.styleFrom(
												backgroundColor: const Color(0xFF2A2C31),
												foregroundColor: const Color(0xFFEFF1F5),
												shape: const RoundedRectangleBorder(),
												elevation: 0,
											),
											onPressed: () async {
												await MeshChannelService.refreshPeers();
											},
											child: const Text(
												'REFRESH SCAN',
												style: TextStyle(
													fontSize: 16,
													fontWeight: FontWeight.w800,
													letterSpacing: 3,
												),
											),
										),
									),
								),
							],
						),
					),
				);
			},
		);

		if (!mounted || selectedPeer == null) return;

		final String? peerId = selectedPeer['id']?.toString();
		if (peerId == null || peerId.isEmpty) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Peer selection failed: missing peer id')),
			);
			return;
		}

		await _controller.openOfflineSession(
			peerId: peerId,
			peerName: selectedPeer['name']?.toString(),
		);

		if (!mounted) return;
		setState(() {
			_activePeerId = peerId;
			_activePeerName = selectedPeer['name']?.toString() ?? peerId;
		});
	}

	List<Map<String, dynamic>> _parsePeers(Map<String, dynamic>? event) {
		final dynamic rawPeers = event?['peers'];
		if (rawPeers is! List) return const <Map<String, dynamic>>[];
		final List<Map<String, dynamic>> peers = <Map<String, dynamic>>[];
		for (final dynamic item in rawPeers) {
			if (item is Map) {
				peers.add(item.cast<String, dynamic>());
			}
		}
		peers.sort((a, b) {
			final int arssi = (a['rssi'] as num?)?.toInt() ?? -110;
			final int brssi = (b['rssi'] as num?)?.toInt() ?? -110;
			return brssi.compareTo(arssi);
		});
		return peers;
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

	String _formatCompactTime(int createdAtMs) {
		final DateTime dt = DateTime.fromMillisecondsSinceEpoch(createdAtMs);
		final String hh = dt.hour.toString().padLeft(2, '0');
		final String mm = dt.minute.toString().padLeft(2, '0');
		return '$hh:$mm';
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
