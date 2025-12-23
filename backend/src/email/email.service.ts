import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';

@Injectable()
export class EmailService implements OnModuleInit {
  private readonly logger = new Logger(EmailService.name);
  private transporter: nodemailer.Transporter;
  private isConfigured = false;

  constructor(private config: ConfigService) {
    const smtpUser = this.config.get<string>('SMTP_USER');
    const smtpPass = this.config.get<string>('SMTP_PASS');
    const smtpHost = this.config.get<string>('SMTP_HOST', 'smtp.gmail.com');
    const smtpPort = this.config.get<number>('SMTP_PORT', 587);

    this.logger.log(`📧 SMTP Config: host=${smtpHost}, port=${smtpPort}, user=${smtpUser ? smtpUser.substring(0, 5) + '***' : 'NOT SET'}, pass=${smtpPass ? '***SET***' : 'NOT SET'}`);

    if (!smtpUser || !smtpPass) {
      this.logger.error('❌ SMTP credentials NOT configured! Set SMTP_USER and SMTP_PASS environment variables.');
      this.logger.error('   For Gmail, use an App Password: https://myaccount.google.com/apppasswords');
    } else {
      this.isConfigured = true;
    }

    this.transporter = nodemailer.createTransport({
      host: smtpHost,
      port: smtpPort,
      secure: smtpPort === 465,
      auth: {
        user: smtpUser,
        pass: smtpPass,
      },
    });
  }

  async onModuleInit() {
    if (!this.isConfigured) {
      this.logger.warn('⚠️ Skipping SMTP verification - credentials not configured');
      return;
    }

    try {
      this.logger.log('🔄 Testing SMTP connection...');
      await this.transporter.verify();
      this.logger.log('✅ SMTP connection verified successfully!');
    } catch (error: any) {
      this.logger.error('❌ SMTP connection failed!');
      this.logger.error(`   Error: ${error.message}`);
      if (error.code === 'EAUTH') {
        this.logger.error('   → Authentication failed. Check your SMTP_USER and SMTP_PASS.');
        this.logger.error('   → For Gmail: Enable 2FA and create an App Password at https://myaccount.google.com/apppasswords');
      } else if (error.code === 'ESOCKET' || error.code === 'ECONNECTION') {
        this.logger.error('   → Connection failed. Check SMTP_HOST and SMTP_PORT.');
      }
    }
  }

  async sendPasswordResetCode(email: string, code: string, firstName?: string): Promise<boolean> {
    const name = firstName || 'Utilisateur';

    if (!this.isConfigured) {
      this.logger.error(`❌ Cannot send email to ${email} - SMTP not configured!`);
      return false;
    }

    this.logger.log(`📤 Attempting to send password reset email to: ${email}`);

    try {
      const info = await this.transporter.sendMail({
        from: `"Vegece" <${this.config.get<string>('SMTP_USER')}>`,
        to: email,
        subject: 'Réinitialisation de votre mot de passe - Vegece',
        html: `
          <!DOCTYPE html>
          <html>
          <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Réinitialisation de mot de passe</title>
          </head>
          <body style="margin: 0; padding: 0; background-color: #0b0b0b; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;">
            <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color: #0b0b0b; padding: 40px 20px;">
              <tr>
                <td align="center">
                  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width: 500px; background: linear-gradient(145deg, #151515 0%, #0f0f0f 100%); border-radius: 24px; border: 1px solid rgba(255, 255, 255, 0.08); box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5);">

                    <!-- Header with gradient accent -->
                    <tr>
                      <td style="padding: 50px 40px 30px 40px; text-align: center; border-bottom: 1px solid rgba(255, 255, 255, 0.05);">
                        <div style="font-size: 42px; margin-bottom: 15px;">🐾</div>
                        <h1 style="margin: 0; font-size: 28px; font-weight: 700; letter-spacing: 4px; color: #fcfcfc;">VEGECE</h1>
                      </td>
                    </tr>

                    <!-- Main content -->
                    <tr>
                      <td style="padding: 40px;">
                        <p style="margin: 0 0 25px 0; font-size: 16px; line-height: 1.7; color: #fcfcfc;">
                          Bonjour <strong style="color: #F2968F;">${name}</strong>,
                        </p>
                        <p style="margin: 0 0 35px 0; font-size: 15px; line-height: 1.7; color: rgba(252, 252, 252, 0.7);">
                          Vous avez demandé à réinitialiser votre mot de passe. Utilisez le code ci-dessous pour continuer :
                        </p>

                        <!-- Code box -->
                        <div style="background: linear-gradient(135deg, #F2968F 0%, #FB676D 100%); border-radius: 16px; padding: 30px; text-align: center; margin: 0 0 35px 0; box-shadow: 0 10px 40px rgba(242, 150, 143, 0.3);">
                          <p style="margin: 0 0 8px 0; font-size: 11px; text-transform: uppercase; letter-spacing: 2px; color: rgba(255, 255, 255, 0.8);">Votre code de vérification</p>
                          <p style="margin: 0; font-size: 40px; font-weight: 700; letter-spacing: 12px; color: #ffffff; text-shadow: 0 2px 10px rgba(0, 0, 0, 0.2);">${code}</p>
                        </div>

                        <!-- Timer info -->
                        <div style="background: rgba(255, 255, 255, 0.03); border: 1px solid rgba(255, 255, 255, 0.06); border-radius: 12px; padding: 16px 20px; margin: 0 0 30px 0;">
                          <p style="margin: 0; font-size: 14px; color: rgba(252, 252, 252, 0.6); text-align: center;">
                            ⏱️ Ce code expire dans <strong style="color: #F2968F;">15 minutes</strong>
                          </p>
                        </div>

                        <!-- Security notice -->
                        <div style="background: rgba(251, 103, 109, 0.08); border: 1px solid rgba(251, 103, 109, 0.15); border-radius: 12px; padding: 18px 20px;">
                          <p style="margin: 0; font-size: 13px; line-height: 1.6; color: rgba(252, 252, 252, 0.6);">
                            🔒 Si vous n'êtes pas à l'origine de cette demande, ignorez simplement cet email. Votre compte reste sécurisé.
                          </p>
                        </div>
                      </td>
                    </tr>

                    <!-- Footer -->
                    <tr>
                      <td style="padding: 30px 40px 40px 40px; border-top: 1px solid rgba(255, 255, 255, 0.05);">
                        <p style="margin: 0 0 8px 0; font-size: 12px; color: rgba(252, 252, 252, 0.3); text-align: center;">
                          © ${new Date().getFullYear()} Vegece — Tous droits réservés
                        </p>
                        <p style="margin: 0; font-size: 11px; color: rgba(252, 252, 252, 0.2); text-align: center;">
                          Cet email a été envoyé automatiquement, merci de ne pas y répondre.
                        </p>
                      </td>
                    </tr>

                  </table>
                </td>
              </tr>
            </table>
          </body>
          </html>
        `,
        text: `Bonjour ${name},\n\nVotre code de réinitialisation Vegece est: ${code}\n\nCe code est valable pendant 15 minutes.\n\nSi vous n'avez pas demandé cette réinitialisation, ignorez cet email.`,
      });

      this.logger.log(`✅ Password reset email sent successfully!`);
      this.logger.log(`   → To: ${email}`);
      this.logger.log(`   → MessageId: ${info.messageId}`);
      this.logger.log(`   → Response: ${info.response}`);
      return true;
    } catch (error: any) {
      this.logger.error(`❌ Failed to send password reset email to ${email}`);
      this.logger.error(`   Error: ${error.message || error}`);
      if (error.code) this.logger.error(`   SMTP Error Code: ${error.code}`);
      if (error.response) this.logger.error(`   SMTP Response: ${error.response}`);
      if (error.responseCode) this.logger.error(`   Response Code: ${error.responseCode}`);
      return false;
    }
  }

  async sendPasswordChangedNotification(email: string, firstName?: string): Promise<boolean> {
    const name = firstName || 'Utilisateur';

    try {
      await this.transporter.sendMail({
        from: `"Vegece" <${this.config.get<string>('SMTP_USER')}>`,
        to: email,
        subject: 'Votre mot de passe a été modifié - Vegece',
        html: `
          <!DOCTYPE html>
          <html>
          <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Mot de passe modifié</title>
          </head>
          <body style="margin: 0; padding: 0; background-color: #0b0b0b; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;">
            <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color: #0b0b0b; padding: 40px 20px;">
              <tr>
                <td align="center">
                  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width: 500px; background: linear-gradient(145deg, #151515 0%, #0f0f0f 100%); border-radius: 24px; border: 1px solid rgba(255, 255, 255, 0.08); box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5);">

                    <!-- Header with gradient accent -->
                    <tr>
                      <td style="padding: 50px 40px 30px 40px; text-align: center; border-bottom: 1px solid rgba(255, 255, 255, 0.05);">
                        <div style="font-size: 42px; margin-bottom: 15px;">🐾</div>
                        <h1 style="margin: 0; font-size: 28px; font-weight: 700; letter-spacing: 4px; color: #fcfcfc;">VEGECE</h1>
                      </td>
                    </tr>

                    <!-- Main content -->
                    <tr>
                      <td style="padding: 40px;">
                        <!-- Success badge -->
                        <div style="background: linear-gradient(135deg, rgba(72, 187, 120, 0.15) 0%, rgba(72, 187, 120, 0.05) 100%); border: 1px solid rgba(72, 187, 120, 0.2); border-radius: 16px; padding: 25px; text-align: center; margin: 0 0 35px 0;">
                          <div style="font-size: 48px; margin-bottom: 12px;">✓</div>
                          <p style="margin: 0; font-size: 18px; font-weight: 600; color: #48bb78;">Mot de passe modifié</p>
                        </div>

                        <p style="margin: 0 0 20px 0; font-size: 16px; line-height: 1.7; color: #fcfcfc;">
                          Bonjour <strong style="color: #F2968F;">${name}</strong>,
                        </p>
                        <p style="margin: 0 0 30px 0; font-size: 15px; line-height: 1.7; color: rgba(252, 252, 252, 0.7);">
                          Votre mot de passe Vegece a été modifié avec succès. Vous pouvez maintenant vous connecter avec votre nouveau mot de passe.
                        </p>

                        <!-- Security warning -->
                        <div style="background: rgba(251, 103, 109, 0.08); border: 1px solid rgba(251, 103, 109, 0.15); border-radius: 12px; padding: 18px 20px;">
                          <p style="margin: 0; font-size: 13px; line-height: 1.6; color: rgba(252, 252, 252, 0.6);">
                            ⚠️ Si vous n'êtes pas à l'origine de cette modification, contactez-nous immédiatement à <strong style="color: #F2968F;">contact@vegece.com</strong>
                          </p>
                        </div>
                      </td>
                    </tr>

                    <!-- Footer -->
                    <tr>
                      <td style="padding: 30px 40px 40px 40px; border-top: 1px solid rgba(255, 255, 255, 0.05);">
                        <p style="margin: 0 0 8px 0; font-size: 12px; color: rgba(252, 252, 252, 0.3); text-align: center;">
                          © ${new Date().getFullYear()} Vegece — Tous droits réservés
                        </p>
                        <p style="margin: 0; font-size: 11px; color: rgba(252, 252, 252, 0.2); text-align: center;">
                          Cet email a été envoyé automatiquement, merci de ne pas y répondre.
                        </p>
                      </td>
                    </tr>

                  </table>
                </td>
              </tr>
            </table>
          </body>
          </html>
        `,
        text: `Bonjour ${name},\n\nVotre mot de passe Vegece a été modifié avec succès.\n\nSi vous n'êtes pas à l'origine de cette modification, contactez-nous immédiatement à contact@vegece.com`,
      });

      this.logger.log(`Password changed notification sent to ${email}`);
      return true;
    } catch (error) {
      this.logger.error(`Failed to send password changed notification to ${email}:`, error);
      return false;
    }
  }
}
