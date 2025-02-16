// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IDisasterInsuranceServiceManager} from "./IDisasterInsuranceServiceManager.sol";
import {MockWeatherOracle} from "./MockWeatherOracle.sol";

contract DisasterImpactPredictor {
    struct ImpactPrediction {
        uint256 estimatedDamageUSD;    // in USD (scaled by 1e2)
        uint256 affectedAreaKM2;        // in square kilometers
        uint256 populationAffected;     // number of people
        uint256 infrastructureRisk;     // 0-100 scale
        uint256 economicDisruption;     // in days
        string[] criticalFacilities;    // affected facilities
        uint256 confidence;             // 0-100 scale
    }

    struct ModelParameters {
        uint256 populationDensity;     // people per km2
        uint256 buildingDensity;       // buildings per km2
        uint256 averagePropertyValue;   // in USD
        uint256 infrastructureScore;    // 0-100 scale
        string[] keyInfrastructure;     // critical infrastructure list
    }

    mapping(bytes32 => ModelParameters) public locationParameters;
    mapping(bytes32 => ImpactPrediction[]) public historicalPredictions;

    event PredictionMade(
        string location,
        uint256 estimatedDamageUSD,
        uint256 populationAffected,
        uint256 confidence
    );

    constructor() {
        // Initialize San Francisco parameters
        bytes32 sfHash = keccak256(bytes("San Francisco"));
        string[] memory sfInfra = new string[](4);
        sfInfra[0] = "Bay Bridge";
        sfInfra[1] = "BART System";
        sfInfra[2] = "SF General Hospital";
        sfInfra[3] = "Port of San Francisco";
        
        locationParameters[sfHash] = ModelParameters({
            populationDensity: 7272,      // 7,272 people per km2
            buildingDensity: 2000,        // 2,000 buildings per km2
            averagePropertyValue: 150000000, // $1.5M average (scaled by 1e2)
            infrastructureScore: 85,
            keyInfrastructure: sfInfra
        });

        // Initialize Miami parameters
        bytes32 miamiHash = keccak256(bytes("Miami"));
        string[] memory miamiInfra = new string[](4);
        miamiInfra[0] = "Port of Miami";
        miamiInfra[1] = "Miami International Airport";
        miamiInfra[2] = "Jackson Memorial Hospital";
        miamiInfra[3] = "Florida Power & Light Stations";
        
        locationParameters[miamiHash] = ModelParameters({
            populationDensity: 4447,      // 4,447 people per km2
            buildingDensity: 1500,        // 1,500 buildings per km2
            averagePropertyValue: 50000000, // $500K average (scaled by 1e2)
            infrastructureScore: 75,
            keyInfrastructure: miamiInfra
        });
    }

    function predictImpact(
        string memory location,
        IDisasterInsuranceServiceManager.DisasterType disasterType,
        uint256 severity,
        MockWeatherOracle.WeatherData memory weatherData
    ) external returns (ImpactPrediction memory) {
        bytes32 locationHash = keccak256(bytes(location));
        require(locationParameters[locationHash].populationDensity > 0, "Location not supported");

        ModelParameters memory params = locationParameters[locationHash];
        
        // Calculate affected area based on disaster type and severity
        uint256 affectedArea = calculateAffectedArea(disasterType, severity);
        
        // Calculate population affected
        uint256 populationAffected = (affectedArea * params.populationDensity);
        
        // Calculate property damage
        uint256 buildingsAffected = (affectedArea * params.buildingDensity);
        uint256 propertyDamage = (buildingsAffected * params.averagePropertyValue * calculateDamageMultiplier(disasterType, severity)) / 100;
        
        // Calculate infrastructure impact
        uint256 infraRisk = calculateInfrastructureRisk(params.infrastructureScore, disasterType, severity);
        
        // Calculate economic disruption
        uint256 disruption = calculateEconomicDisruption(infraRisk, propertyDamage, populationAffected);
        
        // Determine affected facilities
        string[] memory affectedFacilities = determineAffectedFacilities(
            params.keyInfrastructure,
            disasterType,
            severity
        );

        // Calculate confidence based on weather conditions and historical data
        uint256 confidence = calculateConfidence(disasterType, severity, weatherData);

        ImpactPrediction memory prediction = ImpactPrediction({
            estimatedDamageUSD: propertyDamage,
            affectedAreaKM2: affectedArea,
            populationAffected: populationAffected,
            infrastructureRisk: infraRisk,
            economicDisruption: disruption,
            criticalFacilities: affectedFacilities,
            confidence: confidence
        });

        // Store prediction in history
        historicalPredictions[locationHash].push(prediction);

        emit PredictionMade(
            location,
            prediction.estimatedDamageUSD,
            prediction.populationAffected,
            prediction.confidence
        );

        return prediction;
    }

    function calculateAffectedArea(
        IDisasterInsuranceServiceManager.DisasterType disasterType,
        uint256 severity
    ) internal pure returns (uint256) {
        if (disasterType == IDisasterInsuranceServiceManager.DisasterType.EARTHQUAKE) {
            // Exponential growth with magnitude
            return (severity * severity) / 10;
        } else if (disasterType == IDisasterInsuranceServiceManager.DisasterType.HURRICANE) {
            // Larger affected area for hurricanes
            return (severity * severity * 3) / 10;
        } else if (disasterType == IDisasterInsuranceServiceManager.DisasterType.FLOOD) {
            // Flood area based on severity
            return (severity * 4) / 10;
        }
        return severity;
    }

    function calculateDamageMultiplier(
        IDisasterInsuranceServiceManager.DisasterType disasterType,
        uint256 severity
    ) internal pure returns (uint256) {
        uint256 base = 10;
        if (disasterType == IDisasterInsuranceServiceManager.DisasterType.EARTHQUAKE) {
            // Exponential damage increase with magnitude
            return base + (severity * severity) / 100;
        } else if (disasterType == IDisasterInsuranceServiceManager.DisasterType.HURRICANE) {
            // Linear damage increase with wind speed
            return base + (severity / 10);
        } else if (disasterType == IDisasterInsuranceServiceManager.DisasterType.FLOOD) {
            // Damage increases with water level
            return base + (severity * 15) / 100;
        }
        return base;
    }

    function calculateInfrastructureRisk(
        uint256 baseScore,
        IDisasterInsuranceServiceManager.DisasterType disasterType,
        uint256 severity
    ) internal pure returns (uint256) {
        uint256 risk = baseScore;
        
        if (disasterType == IDisasterInsuranceServiceManager.DisasterType.EARTHQUAKE) {
            if (severity > 70) risk += 30;
            else if (severity > 50) risk += 20;
            else risk += 10;
        } else if (disasterType == IDisasterInsuranceServiceManager.DisasterType.HURRICANE) {
            if (severity > 150) risk += 25;
            else if (severity > 120) risk += 15;
            else risk += 5;
        } else if (disasterType == IDisasterInsuranceServiceManager.DisasterType.FLOOD) {
            if (severity > 50) risk += 20;
            else if (severity > 30) risk += 10;
            else risk += 5;
        }
        
        return risk > 100 ? 100 : risk;
    }

    function calculateEconomicDisruption(
        uint256 infraRisk,
        uint256 propertyDamage,
        uint256 populationAffected
    ) internal pure returns (uint256) {
        // Base disruption in days based on infrastructure risk
        uint256 baseDays = infraRisk / 5;
        
        // Add days based on property damage
        uint256 damageImpact = (propertyDamage / 1000000000); // Each $10M adds a day
        
        // Add days based on affected population
        uint256 populationImpact = (populationAffected / 10000); // Each 10K people adds a day
        
        return baseDays + damageImpact + populationImpact;
    }

    function determineAffectedFacilities(
        string[] memory facilities,
        IDisasterInsuranceServiceManager.DisasterType disasterType,
        uint256 severity
    ) internal pure returns (string[] memory) {
        if (severity < 30) {
            // Low severity affects no facilities
            return new string[](0);
        }
        
        uint256 affectedCount;
        if (severity > 70) {
            // High severity affects all facilities
            affectedCount = facilities.length;
        } else if (severity > 50) {
            // Medium-high severity affects 75% of facilities
            affectedCount = (facilities.length * 3) / 4;
        } else {
            // Medium severity affects 50% of facilities
            affectedCount = facilities.length / 2;
        }
        
        string[] memory affected = new string[](affectedCount);
        for (uint256 i = 0; i < affectedCount; i++) {
            affected[i] = facilities[i];
        }
        
        return affected;
    }

    function calculateConfidence(
        IDisasterInsuranceServiceManager.DisasterType disasterType,
        uint256 severity,
        MockWeatherOracle.WeatherData memory weather
    ) internal pure returns (uint256) {
        uint256 confidence = 70; // Base confidence
        
        if (disasterType == IDisasterInsuranceServiceManager.DisasterType.HURRICANE) {
            // Higher confidence with more extreme weather
            if (weather.windSpeed > 100) confidence += 15;
            if (weather.pressure < 980) confidence += 10;
        } else if (disasterType == IDisasterInsuranceServiceManager.DisasterType.FLOOD) {
            if (weather.rainfall > 100) confidence += 15;
            if (weather.humidity > 85) confidence += 10;
        }
        
        // Adjust based on severity
        if (severity > 70) confidence -= 10; // Less confident in extreme scenarios
        else if (severity < 30) confidence += 10; // More confident in mild scenarios
        
        return confidence > 100 ? 100 : confidence;
    }

    function getHistoricalPredictions(string memory location)
        external
        view
        returns (ImpactPrediction[] memory)
    {
        bytes32 locationHash = keccak256(bytes(location));
        return historicalPredictions[locationHash];
    }

    function getLocationParameters(string memory location)
        external
        view
        returns (ModelParameters memory)
    {
        bytes32 locationHash = keccak256(bytes(location));
        require(locationParameters[locationHash].populationDensity > 0, "Location not supported");
        return locationParameters[locationHash];
    }
} 