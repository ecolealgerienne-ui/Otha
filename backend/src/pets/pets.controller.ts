// src/pets/pets.controller.ts
import { Body, Controller, Delete, Get, Param, Patch, Post, Req, UseGuards } from '@nestjs/common';
import { PetsService } from './pets.service';
import { JwtAuthGuard } from '../auth/guards/jwt.guard';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';

@ApiTags('pets')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller({ path: 'pets', version: '1' })
export class PetsController {
  constructor(private readonly pets: PetsService) {}

  @Get('mine')
  listMine(@Req() req: any) {
    return this.pets.listMine(req.user.sub);
  }

  @Post()
  create(@Req() req: any, @Body() dto: any) {
    return this.pets.create(req.user.sub, dto);
  }

  @Patch(':id')
  update(@Req() req: any, @Param('id') id: string, @Body() dto: any) {
    return this.pets.update(req.user.sub, id, dto);
  }

  @Delete(':id')
  delete(@Req() req: any, @Param('id') id: string) {
    return this.pets.delete(req.user.sub, id);
  }

  // Endpoint utilitaire pour réparer un pet mal rattaché
  @Patch(':id/reassign')
  reassign(@Req() req: any, @Param('id') id: string) {
    return this.pets.reassignToOwner(req.user.sub, id);
  }

  // ============ MEDICAL RECORDS ============

  @Get(':petId/medical-records')
  listMedicalRecords(@Req() req: any, @Param('petId') petId: string) {
    return this.pets.listMedicalRecords(req.user.sub, petId);
  }

  @Post(':petId/medical-records')
  createMedicalRecord(@Req() req: any, @Param('petId') petId: string, @Body() dto: any) {
    return this.pets.createMedicalRecord(req.user.sub, petId, dto);
  }

  @Patch(':petId/medical-records/:recordId')
  updateMedicalRecord(
    @Req() req: any,
    @Param('petId') petId: string,
    @Param('recordId') recordId: string,
    @Body() dto: any,
  ) {
    return this.pets.updateMedicalRecord(req.user.sub, petId, recordId, dto);
  }

  @Delete(':petId/medical-records/:recordId')
  deleteMedicalRecord(
    @Req() req: any,
    @Param('petId') petId: string,
    @Param('recordId') recordId: string,
  ) {
    return this.pets.deleteMedicalRecord(req.user.sub, petId, recordId);
  }

  // ============ ACCESS TOKENS (QR Code) ============

  @Post(':petId/access-token')
  generateAccessToken(@Req() req: any, @Param('petId') petId: string) {
    return this.pets.generateAccessToken(req.user.sub, petId);
  }

  // Endpoint public pour le vétérinaire - accès via token
  @Get('by-token/:token')
  getPetByToken(@Param('token') token: string) {
    return this.pets.getPetByToken(token);
  }

  // Vet ajoute un record via token
  @Post('by-token/:token/medical-records')
  createMedicalRecordByToken(
    @Req() req: any,
    @Param('token') token: string,
    @Body() dto: any,
  ) {
    // Le vétérinaire doit être un PRO avec un provider profile
    const vetId = req.user.sub;
    const vetName = dto.vetName || 'Vétérinaire';
    return this.pets.createMedicalRecordByToken(token, vetId, vetName, dto);
  }
}
