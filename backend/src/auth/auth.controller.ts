import { Body, Controller, Get, HttpCode, HttpStatus, Post, Req, UseGuards } from '@nestjs/common';
import { AuthService } from './auth.service';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { IsEmail, IsOptional, IsString, MinLength } from 'class-validator';
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
@ApiTags('auth')
@Controller({ path: 'auth', version: '1' })
export class AuthController {
  constructor(private readonly auth: AuthService) {}
  @Post('register') async register(@Body() dto: RegisterDto) { return this.auth.register(dto.email, dto.password); }
  @HttpCode(HttpStatus.OK) @Post('login') async login(@Body() dto: LoginDto) { return this.auth.login(dto.email, dto.password); }
  @HttpCode(HttpStatus.OK) @Post('google') async google(@Body() dto: GoogleAuthDto) {
    return this.auth.googleAuth(dto.googleId, dto.email, dto.firstName, dto.lastName, dto.photoUrl);
  }
  @ApiBearerAuth() @UseGuards(JwtAuthGuard) @Get('me') async me(@Req() req: any) { return req.user; }
  @HttpCode(HttpStatus.OK) @Post('refresh') async refresh(@Body() dto: RefreshDto) { return this.auth.refreshWithToken(dto.refreshToken); }
}
