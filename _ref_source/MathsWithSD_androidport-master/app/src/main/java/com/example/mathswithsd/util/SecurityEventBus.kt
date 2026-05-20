package com.example.mathswithsd.util

import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.asSharedFlow

object SecurityEventBus {
    private val _events = MutableSharedFlow<SecurityEvent>(extraBufferCapacity = 1)
    val events = _events.asSharedFlow()

    fun postEvent(event: SecurityEvent) {
        _events.tryEmit(event)
    }
}

sealed class SecurityEvent {
    object ViolationDetected : SecurityEvent()
}
