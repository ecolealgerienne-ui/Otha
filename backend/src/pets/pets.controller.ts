// src/pets/pets.controller.ts
import { Body, Controller, Delete, Get, Param, Patch, Post, Req, UseGuards } from '@nestjs/common';
import { PetsService } from './pets.service';
import { JwtAuthGuard } from '../auth/guards/jwt.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
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
  generateAccessToken(@Req() req: any, @Param('petId') petId: string, @Body() body?: { expirationMinutes?: number }) {
    const expirationMinutes = body?.expirationMinutes ?? 30;
    return this.pets.generateAccessToken(req.user.sub, petId, expirationMinutes);
  }

  /**
   * PRO: Generate access token for a pet from a confirmed booking
   * Allows vets to access pet health records after confirmed appointments
   */
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('PRO', 'ADMIN')
  @Post(':petId/pro-access-token')
  generateProAccessToken(@Req() req: any, @Param('petId') petId: string) {
    return this.pets.generateProAccessToken(req.user.sub, petId);
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

  // Vet ajoute une ordonnance via token
  @Post('by-token/:token/prescriptions')
  createPrescriptionByToken(
    @Req() req: any,
    @Param('token') token: string,
    @Body() dto: any,
  ) {
    return this.pets.createPrescriptionByToken(token, req.user.sub, dto);
  }

  // Vet ajoute un suivi de maladie via token
  @Post('by-token/:token/diseases')
  createDiseaseByToken(
    @Req() req: any,
    @Param('token') token: string,
    @Body() dto: any,
  ) {
    return this.pets.createDiseaseByToken(token, req.user.sub, dto);
  }

  // Vet liste les maladies via token
  @Get('by-token/:token/diseases')
  listDiseasesByToken(@Param('token') token: string) {
    return this.pets.listDiseasesByToken(token);
  }

  // Vet récupère le détail d'une maladie via token
  @Get('by-token/:token/diseases/:diseaseId')
  getDiseaseByToken(
    @Param('token') token: string,
    @Param('diseaseId') diseaseId: string,
  ) {
    return this.pets.getDiseaseByToken(token, diseaseId);
  }

  // Vet ajoute une entrée de progression via token
  @Post('by-token/:token/diseases/:diseaseId/progress')
  addProgressEntryByToken(
    @Req() req: any,
    @Param('token') token: string,
    @Param('diseaseId') diseaseId: string,
    @Body() dto: any,
  ) {
    return this.pets.addProgressEntryByToken(token, req.user.sub, diseaseId, dto);
  }

  // Vet ajoute une vaccination via token
  @Post('by-token/:token/vaccinations')
  createVaccinationByToken(
    @Req() req: any,
    @Param('token') token: string,
    @Body() dto: any,
  ) {
    return this.pets.createVaccinationByToken(token, req.user.sub, dto);
  }

  // Vet ajoute un traitement via token
  @Post('by-token/:token/treatments')
  createTreatmentByToken(
    @Req() req: any,
    @Param('token') token: string,
    @Body() dto: any,
  ) {
    return this.pets.createTreatmentByToken(token, req.user.sub, dto);
  }

  // Vet ajoute un poids via token
  @Post('by-token/:token/weight-records')
  createWeightRecordByToken(
    @Req() req: any,
    @Param('token') token: string,
    @Body() dto: any,
  ) {
    return this.pets.createWeightRecordByToken(token, req.user.sub, dto);
  }

  // ============ MEDICAL RECORDS (DELETE by provider) ============

  @Delete('medical-records/:recordId')
  deleteMedicalRecordByProvider(@Req() req: any, @Param('recordId') recordId: string) {
    return this.pets.deleteMedicalRecordByProvider(req.user.sub, recordId);
  }

  // ============ PRESCRIPTIONS ============

  @Get(':petId/prescriptions')
  listPrescriptions(@Req() req: any, @Param('petId') petId: string) {
    return this.pets.listPrescriptions(req.user.sub, petId);
  }

  @Patch('prescriptions/:prescriptionId')
  updatePrescriptionByProvider(
    @Req() req: any,
    @Param('prescriptionId') prescriptionId: string,
    @Body() dto: any,
  ) {
    return this.pets.updatePrescriptionByProvider(req.user.sub, prescriptionId, dto);
  }

  @Delete('prescriptions/:prescriptionId')
  deletePrescriptionByProvider(@Req() req: any, @Param('prescriptionId') prescriptionId: string) {
    return this.pets.deletePrescriptionByProvider(req.user.sub, prescriptionId);
  }

  // ============ DISEASES (UPDATE/DELETE by provider) ============

  @Patch('diseases/:diseaseId')
  updateDiseaseByProvider(
    @Req() req: any,
    @Param('diseaseId') diseaseId: string,
    @Body() dto: any,
  ) {
    return this.pets.updateDiseaseByProvider(req.user.sub, diseaseId, dto);
  }

  @Delete('diseases/:diseaseId')
  deleteDiseaseByProvider(@Req() req: any, @Param('diseaseId') diseaseId: string) {
    return this.pets.deleteDiseaseByProvider(req.user.sub, diseaseId);
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

  // ============ HEALTH STATISTICS ============

  @Get(':petId/health-stats')
  getHealthStats(@Req() req: any, @Param('petId') petId: string) {
    return this.pets.getHealthStats(req.user.sub, petId);
  }

  // ============ DISEASE TRACKING ============

  @Get(':petId/diseases')
  listDiseases(@Req() req: any, @Param('petId') petId: string) {
    return this.pets.listDiseaseTrackings(req.user.sub, petId);
  }

  @Get(':petId/diseases/:diseaseId')
  getDisease(
    @Req() req: any,
    @Param('petId') petId: string,
    @Param('diseaseId') diseaseId: string,
  ) {
    return this.pets.getDiseaseTracking(req.user.sub, petId, diseaseId);
  }

  @Post(':petId/diseases')
  createDisease(@Req() req: any, @Param('petId') petId: string, @Body() dto: any) {
    return this.pets.createDiseaseTracking(req.user.sub, petId, dto);
  }

  @Patch(':petId/diseases/:diseaseId')
  updateDisease(
    @Req() req: any,
    @Param('petId') petId: string,
    @Param('diseaseId') diseaseId: string,
    @Body() dto: any,
  ) {
    return this.pets.updateDiseaseTracking(req.user.sub, petId, diseaseId, dto);
  }

  @Delete(':petId/diseases/:diseaseId')
  deleteDisease(
    @Req() req: any,
    @Param('petId') petId: string,
    @Param('diseaseId') diseaseId: string,
  ) {
    return this.pets.deleteDiseaseTracking(req.user.sub, petId, diseaseId);
  }

  @Post(':petId/diseases/:diseaseId/progress')
  addProgress(
    @Req() req: any,
    @Param('petId') petId: string,
    @Param('diseaseId') diseaseId: string,
    @Body() dto: any,
  ) {
    return this.pets.addProgressEntry(req.user.sub, petId, diseaseId, dto);
  }

  @Delete(':petId/diseases/:diseaseId/progress/:entryId')
  deleteProgress(
    @Req() req: any,
    @Param('petId') petId: string,
    @Param('diseaseId') diseaseId: string,
    @Param('entryId') entryId: string,
  ) {
    return this.pets.deleteProgressEntry(req.user.sub, petId, diseaseId, entryId);
  }
}
