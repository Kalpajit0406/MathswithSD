package com.example.mathswithsd.api

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

class AuthManager(context: Context) {
    private val masterKey = MasterKey.Builder(context)
        .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
        .build()

    private val prefs: SharedPreferences = EncryptedSharedPreferences.create(
        context,
        "secure_auth_prefs",
        masterKey,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )

    fun saveToken(token: String) {
        prefs.edit().putString("access_token", token).apply()
    }

    fun saveUserRole(isAdmin: Boolean) {
        prefs.edit().putBoolean("is_admin", isAdmin).apply()
    }

    fun saveUserPhone(phone: String) {
        prefs.edit().putString("user_phone", phone).apply()
    }

    fun saveUserClass(classNo: Int) {
        prefs.edit().putInt("user_class", classNo).apply()
    }

    fun getToken(): String? {
        return prefs.getString("access_token", null)
    }

    fun isAdmin(): Boolean {
        return prefs.getBoolean("is_admin", false)
    }

    fun getUserPhone(): String? {
        return prefs.getString("user_phone", null)
    }

    fun getUserClass(): Int {
        return prefs.getInt("user_class", 0)
    }

    fun logout() {
        prefs.edit().clear().apply()
    }
}
