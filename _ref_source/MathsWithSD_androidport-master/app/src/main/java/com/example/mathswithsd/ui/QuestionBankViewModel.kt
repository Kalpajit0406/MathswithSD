package com.example.mathswithsd.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.example.mathswithsd.api.RetrofitClient
import com.example.mathswithsd.data.repository.QuestionRepository
import com.example.mathswithsd.data.repository.Result
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

class QuestionBankViewModel(application: Application) : AndroidViewModel(application) {
    private val repository = QuestionRepository(RetrofitClient.create(application))

    private val _state = MutableStateFlow<QuestionListState>(QuestionListState.Loading)
    val state: StateFlow<QuestionListState> = _state

    init {
        loadQuestions()
    }

    fun loadQuestions(classNo: Int? = null, language: String? = null) {
        viewModelScope.launch {
            _state.value = QuestionListState.Loading
            when (val result = repository.getQuestions(classNo, language)) {
                is Result.Success -> _state.value = QuestionListState.Success(result.data)
                is Result.Error -> _state.value = QuestionListState.Error(result.message)
                is Result.Loading -> {}
            }
        }
    }
}
