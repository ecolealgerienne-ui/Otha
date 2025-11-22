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

  // ============ WEIGHT RECORDS ============

  @Get(':petId/weight-records')
  listWeightRecords(@Req() req: any, @Param('petId') petId: string) {
    return this.pets.listWeightRecords(req.user.sub, petId);
  }

  @Post(':petId/weight-records')
  createWeightRecord(@Req() req: any, @Param('petId') petId: string, @Body() dto: any) {
    return this.pets.createWeightRecord(req.user.sub, petId, dto);
  }

  @Delete(':petId/weight-records/:recordId')
  deleteWeightRecord(
    @Req() req: any,
    @Param('petId') petId: string,
    @Param('recordId') recordId: string,
  ) {
    return this.pets.deleteWeightRecord(req.user.sub, petId, recordId);
  }

  // ============ VACCINATIONS ============

  @Get(':petId/vaccinations')
  listVaccinations(@Req() req: any, @Param('petId') petId: string) {
    return this.pets.listVaccinations(req.user.sub, petId);
  }

  @Post(':petId/vaccinations')
  createVaccination(@Req() req: any, @Param('petId') petId: string, @Body() dto: any) {
    return this.pets.createVaccination(req.user.sub, petId, dto);
  }

  @Delete(':petId/vaccinations/:vaccinationId')
  deleteVaccination(
    @Req() req: any,
    @Param('petId') petId: string,
    @Param('vaccinationId') vaccinationId: string,
  ) {
    return this.pets.deleteVaccination(req.user.sub, petId, vaccinationId);
  }

  // ============ TREATMENTS ============

  @Get(':petId/treatments')
  listTreatments(@Req() req: any, @Param('petId') petId: string) {
    return this.pets.listTreatments(req.user.sub, petId);
  }

  @Post(':petId/treatments')
  createTreatment(@Req() req: any, @Param('petId') petId: string, @Body() dto: any) {
    return this.pets.createTreatment(req.user.sub, petId, dto);
  }

  @Patch(':petId/treatments/:treatmentId')
  updateTreatment(
    @Req() req: any,
    @Param('petId') petId: string,
    @Param('treatmentId') treatmentId: string,
    @Body() dto: any,
  ) {
    return this.pets.updateTreatment(req.user.sub, petId, treatmentId, dto);
  }

  @Delete(':petId/treatments/:treatmentId')
  deleteTreatment(
    @Req() req: any,
    @Param('petId') petId: string,
    @Param('treatmentId') treatmentId: string,
  ) {
    return this.pets.deleteTreatment(req.user.sub, petId, treatmentId);
  }

  // ============ ALLERGIES ============

  @Get(':petId/allergies')
  listAllergies(@Req() req: any, @Param('petId') petId: string) {
    return this.pets.listAllergies(req.user.sub, petId);
  }

  @Post(':petId/allergies')
  createAllergy(@Req() req: any, @Param('petId') petId: string, @Body() dto: any) {
    return this.pets.createAllergy(req.user.sub, petId, dto);
  }

  @Delete(':petId/allergies/:allergyId')
  deleteAllergy(
    @Req() req: any,
    @Param('petId') petId: string,
    @Param('allergyId') allergyId: string,
  ) {
    return this.pets.deleteAllergy(req.user.sub, petId, allergyId);
  }

  // ============ PREVENTIVE CARE ============

  @Get(':petId/preventive-care')
  listPreventiveCare(@Req() req: any, @Param('petId') petId: string) {
    return this.pets.listPreventiveCare(req.user.sub, petId);
  }

  @Post(':petId/preventive-care')
  createPreventiveCare(@Req() req: any, @Param('petId') petId: string, @Body() dto: any) {
    return this.pets.createPreventiveCare(req.user.sub, petId, dto);
  }

  @Patch(':petId/preventive-care/:careId')
  updatePreventiveCare(
    @Req() req: any,
    @Param('petId') petId: string,
    @Param('careId') careId: string,
    @Body() dto: any,
  ) {
    return this.pets.updatePreventiveCare(req.user.sub, petId, careId, dto);
  }

  @Delete(':petId/preventive-care/:careId')
  deletePreventiveCare(
    @Req() req: any,
    @Param('petId') petId: string,
    @Param('careId') careId: string,
  ) {
    return this.pets.deletePreventiveCare(req.user.sub, petId, careId);
  }
}
