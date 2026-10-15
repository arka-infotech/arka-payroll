import { Controller, Get } from '@nestjs/common';

@Controller('health')
export class HealthController {
  @Get()
  check() {
    return {
      status: 'ok',
      service: 'arka-payroll-api',
      company: 'Arka Infotech Software Solutions LLP',
      timestamp: new Date().toISOString(),
    };
  }
}
