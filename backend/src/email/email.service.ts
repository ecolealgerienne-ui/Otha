import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';

@Injectable()
export class EmailService {
  private readonly logger = new Logger(EmailService.name);
  private transporter: nodemailer.Transporter;

  constructor(private config: ConfigService) {
    const smtpUser = this.config.get<string>('SMTP_USER');
    const smtpPass = this.config.get<string>('SMTP_PASS');
    const smtpHost = this.config.get<string>('SMTP_HOST', 'smtp.gmail.com');
    const smtpPort = this.config.get<number>('SMTP_PORT', 587);

    this.logger.log(`📧 SMTP Config: host=${smtpHost}, port=${smtpPort}, user=${smtpUser ? smtpUser.substring(0, 5) + '***' : 'NOT SET'}`);

    if (!smtpUser || !smtpPass) {
      this.logger.warn('⚠️ SMTP credentials not configured! Email sending will fail.');
    }

    this.transporter = nodemailer.createTransport({
      host: smtpHost,
      port: smtpPort,
      secure: false,
      auth: {
        user: smtpUser,
        pass: smtpPass,
      },
    });
  }

  async sendPasswordResetCode(email: string, code: string, firstName?: string): Promise<boolean> {
    const name = firstName || 'Utilisateur';

    try {
      await this.transporter.sendMail({
        from: `"Vegece" <${this.config.get<string>('SMTP_USER')}>`,
        to: email,
        subject: 'Réinitialisation de votre mot de passe - Vegece',
        html: `
          <!DOCTYPE html>
          <html>
          <head>
            <meta charset="utf-8">
            <style>
              body { font-family: Arial, sans-serif; background-color: #f5f5f5; margin: 0; padding: 20px; }
              .container { max-width: 500px; margin: 0 auto; background: white; border-radius: 12px; padding: 40px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
              .logo { text-align: center; margin-bottom: 30px; }
              .logo h1 { color: #4CAF50; margin: 0; font-size: 32px; }
              .code { background: linear-gradient(135deg, #4CAF50 0%, #45a049 100%); color: white; font-size: 36px; font-weight: bold; text-align: center; padding: 20px; border-radius: 8px; letter-spacing: 8px; margin: 30px 0; }
              .message { color: #333; font-size: 16px; line-height: 1.6; }
              .warning { background: #fff3cd; border: 1px solid #ffc107; border-radius: 8px; padding: 15px; margin-top: 20px; color: #856404; font-size: 14px; }
              .footer { text-align: center; margin-top: 30px; color: #999; font-size: 12px; }
            </style>
          </head>
          <body>
            <div class="container">
              <div class="logo">
                <h1>🐾 Vegece</h1>
              </div>
              <p class="message">Bonjour <strong>${name}</strong>,</p>
              <p class="message">Vous avez demandé à réinitialiser votre mot de passe. Voici votre code de vérification :</p>
              <div class="code">${code}</div>
              <p class="message">Ce code est valable pendant <strong>15 minutes</strong>.</p>
              <div class="warning">
                ⚠️ Si vous n'avez pas demandé cette réinitialisation, ignorez cet email. Votre compte reste sécurisé.
              </div>
              <div class="footer">
                <p>© ${new Date().getFullYear()} Vegece - Tous droits réservés</p>
                <p>Cet email a été envoyé automatiquement, merci de ne pas y répondre.</p>
              </div>
            </div>
          </body>
          </html>
        `,
        text: `Bonjour ${name},\n\nVotre code de réinitialisation Vegece est: ${code}\n\nCe code est valable pendant 15 minutes.\n\nSi vous n'avez pas demandé cette réinitialisation, ignorez cet email.`,
      });

      this.logger.log(`✅ Password reset email sent to ${email}`);
      return true;
    } catch (error: any) {
      this.logger.error(`❌ Failed to send password reset email to ${email}`);
      this.logger.error(`Error: ${error.message || error}`);
      if (error.code) this.logger.error(`SMTP Error Code: ${error.code}`);
      if (error.response) this.logger.error(`SMTP Response: ${error.response}`);
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
            <style>
              body { font-family: Arial, sans-serif; background-color: #f5f5f5; margin: 0; padding: 20px; }
              .container { max-width: 500px; margin: 0 auto; background: white; border-radius: 12px; padding: 40px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
              .logo { text-align: center; margin-bottom: 30px; }
              .logo h1 { color: #4CAF50; margin: 0; font-size: 32px; }
              .success { background: #d4edda; border: 1px solid #28a745; border-radius: 8px; padding: 20px; margin: 20px 0; color: #155724; text-align: center; }
              .success-icon { font-size: 48px; margin-bottom: 10px; }
              .message { color: #333; font-size: 16px; line-height: 1.6; }
              .warning { background: #f8d7da; border: 1px solid #dc3545; border-radius: 8px; padding: 15px; margin-top: 20px; color: #721c24; font-size: 14px; }
              .footer { text-align: center; margin-top: 30px; color: #999; font-size: 12px; }
            </style>
          </head>
          <body>
            <div class="container">
              <div class="logo">
                <h1>🐾 Vegece</h1>
              </div>
              <div class="success">
                <div class="success-icon">✅</div>
                <strong>Mot de passe modifié avec succès</strong>
              </div>
              <p class="message">Bonjour <strong>${name}</strong>,</p>
              <p class="message">Votre mot de passe Vegece a été modifié avec succès.</p>
              <div class="warning">
                ⚠️ Si vous n'êtes pas à l'origine de cette modification, contactez-nous immédiatement à contact@vegece.com
              </div>
              <div class="footer">
                <p>© ${new Date().getFullYear()} Vegece - Tous droits réservés</p>
              </div>
            </div>
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
