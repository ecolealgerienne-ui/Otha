import { ConflictException, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../prisma/prisma.service';
import * as argon2 from 'argon2';
import { ConfigService } from '@nestjs/config';
@Injectable()
export class AuthService {
  constructor(private prisma: PrismaService, private jwt: JwtService, private config: ConfigService) {}
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
}
