import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { environment } from '../../environments/environment';

@Injectable({
  providedIn: 'root'
})
export class StockpileService {
  constructor(private http: HttpClient) { }

  createStockpile(stockpileData: any) {
    return this.http.post(`${environment.apiUrl}/stockpiles`, stockpileData);
  }

  getAllStockpiles() {
    return this.http.get(`${environment.apiUrl}/stockpiles`);
  }
} 