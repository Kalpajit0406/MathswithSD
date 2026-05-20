package com.example.mathswithsd.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.example.mathswithsd.api.RetrofitClient
import com.example.mathswithsd.data.repository.Result
import com.example.mathswithsd.data.repository.StudentRepository
import com.example.mathswithsd.models.User
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

sealed class StudentListState {
    object Loading : StudentListState()
    data class Success(
        val pending: List<User>,
        val verified: List<User>,
        val rejected: List<User>
    ) : StudentListState()
    data class Error(val message: String) : StudentListState()
}

class ManageStudentsViewModel(application: Application) : AndroidViewModel(application) {
    private val repository = StudentRepository(RetrofitClient.create(application))

    private val _state = MutableStateFlow<StudentListState>(StudentListState.Loading)
    val state: StateFlow<StudentListState> = _state

    init {
        loadStudents()
    }

    fun loadStudents() {
        viewModelScope.launch {
            _state.value = StudentListState.Loading
            when (val result = repository.getAllStudents()) {
                is Result.Success -> {
                    val (pending, verified, rejected) = result.data
                    _state.value = StudentListState.Success(pending, verified, rejected)
                }
                is Result.Error -> _state.value = StudentListState.Error(result.message)
                is Result.Loading -> {}
            }
        }
    }

    fun acceptStudent(id: String) {
        viewModelScope.launch {
            when (val result = repository.acceptStudent(id)) {
                is Result.Success -> loadStudents() // Refresh list
                is Result.Error -> {
                    // Handle error if needed (maybe show toast via side effect)
                }
                is Result.Loading -> {}
            }
        }
    }

    fun rejectStudent(id: String) {
        viewModelScope.launch {
            when (val result = repository.rejectStudent(id)) {
                is Result.Success -> loadStudents() // Refresh list
                is Result.Error -> {
                    // Handle error if needed
                }
                is Result.Loading -> {}
            }
        }
    }
}
