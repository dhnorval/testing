import { Component } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { Router } from '@angular/router';
import { StockpileService } from '../../services/stockpile.service';

@Component({
  selector: 'app-stockpile-form',
  templateUrl: './stockpile-form.component.html',
  styleUrls: ['./stockpile-form.component.scss']
})
export class StockpileFormComponent {
  stockpileForm: FormGroup;
  error = '';
  loading = false;

  constructor(
    private formBuilder: FormBuilder,
    private router: Router,
    private stockpileService: StockpileService
  ) {
    this.stockpileForm = this.formBuilder.group({
      name: ['', Validators.required],
      material: ['', Validators.required],
      grade: ['', Validators.required],
      length: ['', [Validators.required, Validators.min(0)]],
      width: ['', [Validators.required, Validators.min(0)]],
      height: ['', [Validators.required, Validators.min(0)]],
      volume: ['', [Validators.required, Validators.min(0)]],
      location: this.formBuilder.group({
        coordinates: this.formBuilder.array([
          ['', [Validators.required]], // longitude
          ['', [Validators.required]]  // latitude
        ])
      })
    });
  }

  onSubmit() {
    if (this.stockpileForm.invalid) {
      return;
    }

    this.loading = true;
    this.stockpileService.createStockpile(this.stockpileForm.value).subscribe({
      next: () => {
        this.router.navigate(['/stockpiles']);
      },
      error: error => {
        this.error = error.error?.message || 'Failed to create stockpile';
        this.loading = false;
      }
    });
  }

  // Helper method to calculate volume automatically
  calculateVolume() {
    const length = this.stockpileForm.get('length')?.value;
    const width = this.stockpileForm.get('width')?.value;
    const height = this.stockpileForm.get('height')?.value;
    if (length && width && height) {
      const volume = length * width * height;
      this.stockpileForm.patchValue({ volume });
    }
  }
} 