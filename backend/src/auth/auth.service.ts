import { BadRequestException, ConflictException, Injectable, NotFoundException, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../prisma/prisma.service';
import * as argon2 from 'argon2';
import { ConfigService } from '@nestjs/config';
import { EmailService } from '../email/email.service';

@Injectable()
export class AuthService {
  // Store reset codes in memory (in production, use Redis)
  private resetCodes = new Map<string, { code: string; expiresAt: Date; attempts: number }>();

  constructor(
    private prisma: PrismaService,
    private jwt: JwtService,
    private config: ConfigService,
    private email: EmailService,
  ) {}
  async register(email: string, password: string) {
    const existing = await this.prisma.user.findUnique({ where: { email } });
    if (existing) throw new ConflictException('Email already in use');
    const hash = await argon2.hash(password);
    const user = await this.prisma.user.create({ data: { email, password: hash }, select: { id: true, email: true, role: true, createdAt: true } });
    const tokens = await this.issueTokens(user.id, user.role);
    return { user, ...tokens };
  }
  async login(email: string, password: string) {
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user || !user.password) throw new UnauthorizedException('Invalid credentials');
    const ok = await argon2.verify(user.password, password);
    if (!ok) throw new UnauthorizedException('Invalid credentials');
    const tokens = await this.issueTokens(user.id, user.role);
    return { user: { id: user.id, email: user.email, role: user.role }, ...tokens };
  }
  async refresh(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new UnauthorizedException();
    const tokens = await this.issueTokens(user.id, user.role);
    return tokens;
  }

  async refreshWithToken(refreshToken: string) {
    try {
      const payload = await this.jwt.verifyAsync(refreshToken, {
        secret: this.config.get<string>('JWT_REFRESH_SECRET'),
      });

      if (payload.typ !== 'refresh') {
        throw new UnauthorizedException('Invalid token type');
      }

      const user = await this.prisma.user.findUnique({ where: { id: payload.sub } });
      if (!user) throw new UnauthorizedException('User not found');

      const tokens = await this.issueTokens(user.id, user.role);
      return tokens;
    } catch (error) {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }
  }

  async googleAuth(googleId: string, email: string, firstName?: string, lastName?: string, photoUrl?: string) {
    // Chercher utilisateur par googleId ou email
    let user = await this.prisma.user.findFirst({
      where: { OR: [{ googleId }, { email }] },
    });

    if (user) {
      // Si user existe mais n'a pas de googleId, on le met à jour
      if (!user.googleId) {
        user = await this.prisma.user.update({
          where: { id: user.id },
          data: { googleId },
        });
      }
    } else {
      // Créer nouveau user avec Google
      user = await this.prisma.user.create({
        data: {
          email,
          googleId,
          password: null, // Pas de password pour Google auth
          firstName: firstName || null,
          lastName: lastName || null,
          photoUrl: photoUrl || null,
        },
      });
    }

    const tokens = await this.issueTokens(user.id, user.role);
    return {
      user: {
        id: user.id,
        email: user.email,
        role: user.role,
        firstName: user.firstName,
        lastName: user.lastName,
        photoUrl: user.photoUrl,
      },
      ...tokens,
    };
  }

  private async issueTokens(userId: string, role: string) {
    // ✅ Token d'acces valide 30 jours pour rester connecte longtemps
    const accessTtl = this.config.get<string>('JWT_ACCESS_TTL', '30d');
    // ✅ Refresh token valide 60 jours (backup)
    const refreshTtl = this.config.get<string>('JWT_REFRESH_TTL', '60d');
    const access = await this.jwt.signAsync({ sub: userId, role }, { secret: this.config.get<string>('JWT_ACCESS_SECRET')!, expiresIn: accessTtl });
    const refresh = await this.jwt.signAsync({ sub: userId, typ: 'refresh' }, { secret: this.config.get<string>('JWT_REFRESH_SECRET')!, expiresIn: refreshTtl });
    return { accessToken: access, refreshToken: refresh };
  }

  // ==================== PASSWORD RESET ====================

  async forgotPassword(email: string): Promise<{ success: boolean; message: string }> {
    // Find user by email
    const user = await this.prisma.user.findUnique({ where: { email } });

    // Always return success to prevent email enumeration attacks
    if (!user) {
      return { success: true, message: 'Si cet email existe, un code de réinitialisation a été envoyé.' };
    }

    // Check if user has a password (not Google-only account)
    if (!user.password && user.googleId) {
      return { success: false, message: 'Ce compte utilise Google pour se connecter. Aucun mot de passe à réinitialiser.' };
    }

    // Generate 6-digit code
    const code = Math.floor(100000 + Math.random() * 900000).toString();

    // Store code with 15 min expiry
    this.resetCodes.set(email.toLowerCase(), {
      code,
      expiresAt: new Date(Date.now() + 15 * 60 * 1000), // 15 minutes
      attempts: 0,
    });

    // Send email
    const sent = await this.email.sendPasswordResetCode(email, code, user.firstName || undefined);

    if (!sent) {
      throw new BadRequestException('Erreur lors de l\'envoi de l\'email. Réessayez plus tard.');
    }

    return { success: true, message: 'Un code de réinitialisation a été envoyé à votre adresse email.' };
  }

  async verifyResetCode(email: string, code: string): Promise<{ valid: boolean }> {
    const stored = this.resetCodes.get(email.toLowerCase());

    if (!stored) {
      return { valid: false };
    }

    // Check expiry
    if (new Date() > stored.expiresAt) {
      this.resetCodes.delete(email.toLowerCase());
      return { valid: false };
    }

    // Check attempts (max 5)
    if (stored.attempts >= 5) {
      this.resetCodes.delete(email.toLowerCase());
      throw new BadRequestException('Trop de tentatives. Demandez un nouveau code.');
    }

    // Increment attempts
    stored.attempts++;

    // Check code
    if (stored.code !== code) {
      return { valid: false };
    }

    return { valid: true };
  }

  async resetPassword(email: string, code: string, newPassword: string): Promise<{ success: boolean; message: string }> {
    // Verify code first
    const verification = await this.verifyResetCode(email, code);
    if (!verification.valid) {
      throw new BadRequestException('Code invalide ou expiré.');
    }

    // Find user
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user) {
      throw new NotFoundException('Utilisateur non trouvé.');
    }

    // Validate password strength
    if (newPassword.length < 8) {
      throw new BadRequestException('Le mot de passe doit contenir au moins 8 caractères.');
    }

    // Hash new password
    const hash = await argon2.hash(newPassword);

    // Update user password
    await this.prisma.user.update({
      where: { id: user.id },
      data: { password: hash },
    });

    // Delete used code
    this.resetCodes.delete(email.toLowerCase());

    // Send confirmation email
    await this.email.sendPasswordChangedNotification(email, user.firstName || undefined);

    return { success: true, message: 'Votre mot de passe a été modifié avec succès.' };
  }
}
