package com.blackoutlink.domain.usecase

data class MessageValidationResult(
    val valid: Boolean,
    val errorCode: String? = null
)

class MessageValidationUseCase {
    fun validateDraft(content: String): MessageValidationResult {
        return if (content.trim().isEmpty()) {
            MessageValidationResult(valid = false, errorCode = "empty_draft")
        } else {
            MessageValidationResult(valid = true)
        }
    }
}
