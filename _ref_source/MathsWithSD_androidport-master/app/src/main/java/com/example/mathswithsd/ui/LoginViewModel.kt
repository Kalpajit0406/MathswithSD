package com.example.mathswithsd.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.example.mathswithsd.api.AuthManager
import com.example.mathswithsd.api.RetrofitClient
import com.example.mathswithsd.data.repository.AuthRepository
import com.example.mathswithsd.data.repository.Result
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

sealed class LoginState {
    object Idle : LoginState()
    object Loading : LoginState()
    data class Success(val message: String) : LoginState()
    data class Error(val message: String) : LoginState()
}

class LoginViewModel(application: Application) : AndroidViewModel(application) {
    private val _loginState = MutableStateFlow<LoginState>(LoginState.Idle)
    val loginState: StateFlow<LoginState> = _loginState

    private val authRepository = AuthRepository(
        RetrofitClient.create(application),
        AuthManager(application)
    )

    fun login(mobile: String, password: String) {
        if (mobile.isBlank() || password.isBlank()) {
            _loginState.value = LoginState.Error("Please enter mobile and password")
            return
        }

        viewModelScope.launch {
            _loginState.value = LoginState.Loading
            
            when (val result = authRepository.login(mobile, password)) {
                is Result.Success -> {
                    _loginState.value = LoginState.Success(result.data)
                }
                is Result.Error -> {
                    _loginState.value = LoginState.Error(result.message)
                }
                is Result.Loading -> {}
            }
        }
    }
}
