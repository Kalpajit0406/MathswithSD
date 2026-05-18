package com.example.mathswithsd.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.example.mathswithsd.api.RetrofitClient
import com.example.mathswithsd.data.repository.AnnouncementRepository
import com.example.mathswithsd.data.repository.Result
import com.example.mathswithsd.data.room.ExamDatabase
import com.example.mathswithsd.models.AnnouncementResponse
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

sealed class AnnouncementState {
    object Idle : AnnouncementState()
    object Loading : AnnouncementState()
    data class Success(val announcements: List<AnnouncementResponse>) : AnnouncementState()
    data class Error(val message: String) : AnnouncementState()
}

sealed class CreateAnnouncementState {
    object Idle : CreateAnnouncementState()
    object Loading : CreateAnnouncementState()
    object Success : CreateAnnouncementState()
    data class Error(val message: String) : CreateAnnouncementState()
}

class AnnouncementViewModel(application: Application) : AndroidViewModel(application) {

    private val db = ExamDatabase.getDatabase(application)
    private val repo = AnnouncementRepository(
        RetrofitClient.create(application),
        db.announcementDao()
    )

    private val _state = MutableStateFlow<AnnouncementState>(AnnouncementState.Idle)
    val state: StateFlow<AnnouncementState> = _state

    private val _createState = MutableStateFlow<CreateAnnouncementState>(CreateAnnouncementState.Idle)
    val createState: StateFlow<CreateAnnouncementState> = _createState

    fun loadAnnouncements(targetClass: String? = null) {
        viewModelScope.launch {
            _state.value = AnnouncementState.Loading
            when (val result = repo.getAnnouncements(targetClass)) {
                is Result.Success -> _state.value = AnnouncementState.Success(result.data)
                is Result.Error  -> _state.value = AnnouncementState.Error(result.message)
                is Result.Loading -> {}
            }
        }
    }

    fun refresh(targetClass: String? = null) = loadAnnouncements(targetClass)

    fun createAnnouncement(title: String, message: String, image: String?, targetClass: String) {
        viewModelScope.launch {
            _createState.value = CreateAnnouncementState.Loading
            when (val result = repo.createAnnouncement(title, message, image, targetClass)) {
                is Result.Success -> {
                    _createState.value = CreateAnnouncementState.Success
                    loadAnnouncements() // refresh list
                }
                is Result.Error -> _createState.value = CreateAnnouncementState.Error(result.message)
                is Result.Loading -> {}
            }
        }
    }

    fun resetCreateState() {
        _createState.value = CreateAnnouncementState.Idle
    }
}
