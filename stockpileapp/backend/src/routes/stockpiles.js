const express = require('express');
const Stockpile = require('../models/Stockpile');
const { auth, authorize } = require('../middleware/auth');

const router = express.Router();

// Get all stockpiles
router.get('/', auth, async (req, res) => {
    try {
        const stockpiles = await Stockpile.findAll();
        res.json(stockpiles);
    } catch (error) {
        console.error('Fetch stockpiles error:', error);
        res.status(500).json({ error: 'Failed to fetch stockpiles' });
    }
});

// Get single stockpile
router.get('/:id', auth, async (req, res) => {
    try {
        const stockpile = await Stockpile.findById(req.params.id);
        if (!stockpile) {
            return res.status(404).json({ error: 'Stockpile not found' });
        }
        res.json(stockpile);
    } catch (error) {
        console.error('Fetch stockpile error:', error);
        res.status(500).json({ error: 'Failed to fetch stockpile' });
    }
});

// Create new stockpile
router.post('/', auth, authorize('admin', 'supervisor'), async (req, res) => {
    try {
        const stockpile = await Stockpile.create({
            ...req.body,
            responsibleTeamId: req.user.id
        });
        res.status(201).json(stockpile);
    } catch (error) {
        console.error('Create stockpile error:', error);
        res.status(400).json({ error: 'Failed to create stockpile' });
    }
});

// Update stockpile
router.put('/:id', auth, authorize('admin', 'supervisor'), async (req, res) => {
    try {
        const stockpile = await Stockpile.update(req.params.id, {
            ...req.body,
            responsibleTeamId: req.user.id
        });
        if (!stockpile) {
            return res.status(404).json({ error: 'Stockpile not found' });
        }
        res.json(stockpile);
    } catch (error) {
        console.error('Update stockpile error:', error);
        res.status(400).json({ error: 'Failed to update stockpile' });
    }
});

// Delete stockpile
router.delete('/:id', auth, authorize('admin'), async (req, res) => {
    try {
        const stockpile = await Stockpile.delete(req.params.id);
        if (!stockpile) {
            return res.status(404).json({ error: 'Stockpile not found' });
        }
        res.json({ message: 'Stockpile deleted successfully' });
    } catch (error) {
        console.error('Delete stockpile error:', error);
        res.status(500).json({ error: 'Failed to delete stockpile' });
    }
});

module.exports = router; 