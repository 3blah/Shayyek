package com.example.shayyek

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Properties
import java.util.concurrent.Executors
import javax.mail.Authenticator
import javax.mail.Message
import javax.mail.PasswordAuthentication
import javax.mail.Session
import javax.mail.Transport
import javax.mail.internet.InternetAddress
import javax.mail.internet.MimeMessage

class MainActivity : FlutterActivity() {
    private val EMAIL_CHANNEL = "email_channel"
    private val USERNAME = "emaal7739@gmail.com"
    private val APP_PASSWORD = "kylbjhalbyylnmbd"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, EMAIL_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sendEmail" -> {
                        val email = call.argument<String>("email")
                        val subject = call.argument<String>("subject")
                        val message = call.argument<String>("message")

                        if (email.isNullOrBlank() || subject.isNullOrBlank() || message.isNullOrBlank()) {
                            result.error("INVALID_ARGUMENTS", "Missing data", null)
                            return@setMethodCallHandler
                        }

                        Executors.newSingleThreadExecutor().execute {
                            try {
                                sendStyledEmail(email, subject, message)
                                runOnUiThread {
                                    result.success("Email Sent")
                                }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("EMAIL_SEND_FAILED", e.message, null)
                                }
                            }
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun sendStyledEmail(email: String, subject: String, bodyHtml: String) {
        val props = Properties().apply {
            put("mail.smtp.auth", "true")
            put("mail.smtp.starttls.enable", "true")
            put("mail.smtp.host", "smtp.gmail.com")
            put("mail.smtp.port", "587")
        }

        val session = Session.getInstance(props, object : Authenticator() {
            override fun getPasswordAuthentication(): PasswordAuthentication {
                return PasswordAuthentication(USERNAME, APP_PASSWORD)
            }
        })

        val wrappedHtml = """
            <html>
            <body style="font-family: Arial, sans-serif; background:#f6fbff; padding:20px;">
              <div style="max-width:600px; margin:auto; background:#ffffff; padding:22px; border-radius:16px; border:1px solid #e8f3f6;">
                <div style="text-align:center; margin-bottom:12px;">
                  <h2 style="margin:0; color:#0B1F2A; letter-spacing:0.5px;">SHAYYEK</h2>
                  <small style="color:#2DB7FF; font-weight:700;">Smart Parking System</small>
                </div>
                <div style="height:1px; background:#e9eef2; margin:16px 0;"></div>
                <div style="color:#1f2937; line-height:1.7; font-size:14px;">
                  $bodyHtml
                </div>
                <div style="height:1px; background:#e9eef2; margin:22px 0;"></div>
                <p style="font-size:12px; color:#6b7280; text-align:center; margin:0;">
                  This is an automated message from SHAYYEK. Please do not reply.
                </p>
              </div>
            </body>
            </html>
        """.trimIndent()

        val mimeMessage = MimeMessage(session).apply {
            setFrom(InternetAddress(USERNAME, "SHAYYEK"))
            setRecipients(Message.RecipientType.TO, InternetAddress.parse(email))
            setSubject(subject)
            setContent(wrappedHtml, "text/html; charset=utf-8")
        }

        Transport.send(mimeMessage)
    }
}