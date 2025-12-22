import { Body, Controller, Get, HttpCode, HttpStatus, Post, Req, UseGuards } from '@nestjs/common';
import { AuthService } from './auth.service';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { IsEmail, IsOptional, IsString, Length, MinLength } from 'class-validator';
import { JwtAuthGuard } from './guards/jwt.guard';

class RegisterDto { @IsEmail() email!: string; @IsString() @MinLength(6) password!: string; }
class LoginDto { @IsEmail() email!: string; @IsString() @MinLength(6) password!: string; }
class RefreshDto { @IsString() refreshToken!: string; }
class GoogleAuthDto {
  @IsString() googleId!: string;
  @IsEmail() email!: string;
  @IsOptional() @IsString() firstName?: string;
  @IsOptional() @IsString() lastName?: string;
  @IsOptional() @IsString() photoUrl?: string;
}

// Password Reset DTOs
class ForgotPasswordDto {
  @IsEmail() email!: string;
}

class VerifyResetCodeDto {
  @IsEmail() email!: string;
  @IsString() @Length(6, 6) code!: string;
}

class ResetPasswordDto {
  @IsEmail() email!: string;
  @IsString() @Length(6, 6) code!: string;
  @IsString() @MinLength(8) newPassword!: string;
}

@ApiTags('auth')
@Controller({ path: 'auth', version: '1' })
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('register')
  async register(@Body() dto: RegisterDto) {
    return this.auth.register(dto.email, dto.password);
  }

  @HttpCode(HttpStatus.OK)
  @Post('login')
  async login(@Body() dto: LoginDto) {
    return this.auth.login(dto.email, dto.password);
  }

  @HttpCode(HttpStatus.OK)
  @Post('google')
  async google(@Body() dto: GoogleAuthDto) {
    return this.auth.googleAuth(dto.googleId, dto.email, dto.firstName, dto.lastName, dto.photoUrl);
  }

  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @Get('me')
  async me(@Req() req: any) {
    return req.user;
  }

  @HttpCode(HttpStatus.OK)
  @Post('refresh')
  async refresh(@Body() dto: RefreshDto) {
    return this.auth.refreshWithToken(dto.refreshToken);
  }

  // ==================== PASSWORD RESET ENDPOINTS ====================

  @ApiOperation({ summary: 'Demander un code de réinitialisation par email' })
  @HttpCode(HttpStatus.OK)
  @Post('forgot-password')
  async forgotPassword(@Body() dto: ForgotPasswordDto) {
    return this.auth.forgotPassword(dto.email);
  }

  @ApiOperation({ summary: 'Vérifier le code de réinitialisation' })
  @HttpCode(HttpStatus.OK)
  @Post('verify-reset-code')
  async verifyResetCode(@Body() dto: VerifyResetCodeDto) {
    return this.auth.verifyResetCode(dto.email, dto.code);
  }

  @ApiOperation({ summary: 'Réinitialiser le mot de passe avec le code' })
  @HttpCode(HttpStatus.OK)
  @Post('reset-password')
  async resetPassword(@Body() dto: ResetPasswordDto) {
    return this.auth.resetPassword(dto.email, dto.code, dto.newPassword);
  }
}
