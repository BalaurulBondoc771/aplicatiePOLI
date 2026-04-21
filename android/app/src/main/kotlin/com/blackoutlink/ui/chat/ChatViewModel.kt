package com.blackoutlink.ui.chat

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.blackoutlink.data.repository.MeshRepository
import com.blackoutlink.data.storage.MessageEntity
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class ChatUiState(
    val messages: List<MessageEntity> = emptyList(),
    val draftMessage: String = ""
)

class ChatViewModel(
    private val repository: MeshRepository,
    private val localNodeId: String = "LOCAL_NODE"
) : ViewModel() {
    private val _uiState = MutableStateFlow(ChatUiState())
    val uiState: StateFlow<ChatUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            repository.observeMessages().collect {
                _uiState.value = _uiState.value.copy(messages = it)
            }
        }
    }

    fun onDraftChanged(value: String) {
        _uiState.value = _uiState.value.copy(draftMessage = value)
    }

    fun sendMessage() {
        val content = _uiState.value.draftMessage.trim()
        if (content.isEmpty()) return
        viewModelScope.launch {
            repository.sendTextMessage(
                senderId = localNodeId,
                receiverId = null,
                content = content
            )
            _uiState.value = _uiState.value.copy(draftMessage = "")
        }
    }
}
