
classdef PGF < SampleBasedJointlyGaussianPrediction
    % The Progressive Gaussian Filter (PGF).
    %
    % PGF Methods:
    %   PGF                       - Class constructor.
    %   copy                      - Copy a Filter instance.
    %   copyWithName              - Copy a Filter instance and give the copy a new name / description.
    %   getName                   - Get the filter name / description.
    %   setColor                  - Set the filter color / plotting properties.
    %   getColor                  - Get the current filter color / plotting properties.
    %   setState                  - Set the system state.
    %   getState                  - Get the current system state.
    %   getStateDim               - Get the dimension of the current system state.
    %   predict                   - Perform a time update (prediction step).
    %   update                    - Perform a measurement update (filter step) using the given measurement(s).
    %   step                      - Perform a combined time and measurement update.
    %   getPointEstimate          - Get a point estimate of the current system state.
    %   setStateDecompDim         - Set the dimension of the unobservable part of the system state.
    %   getStateDecompDim         - Get the dimension of the unobservable part of the system state.
    %   setNumSamples             - Set an absolute number of samples used by the PGF for prediction and upate.
    %   setNumSamplesByFactor     - Set a linear factor to determine the number of samples used by the PGF for prediction and upate.
    %   setMaxNumProgSteps        - Set the maximum number of allowed progression steps.
    %   getMaxNumProgSteps        - Get the current maximum number of allowed progression steps.
    %   getNumProgSteps           - Get the number of progression steps required by the last measurement update.
    
    % Literature:
    %   Jannik Steinbring, Antonio Zea, and Uwe D. Hanebeck,
    %   Semi-Analytic Progressive Gaussian Filtering,
    %   Proceedings of the 2016 IEEE International Conference on Multisensor Fusion and Integration for Intelligent Systems (MFI 2016),
    %   Baden-Baden, Germany, Sep 2016.
    %
    %   Jannik Steinbring and Uwe D. Hanebeck,
    %   GPU-Accelerated Progressive Gaussian Filtering with Applications to Extended Object Tracking,
    %   Proceedings of the 18th International Conference on Information Fusion (Fusion 2015),
    %   Washington D. C., USA, Jul 2015.
    %
    %   Jannik Steinbring and Uwe D. Hanebeck,
    %   Progressive Gaussian Filtering Using Explicit Likelihoods,
    %   Proceedings of the 17th International Conference on Information Fusion (Fusion 2014),
    %   Salamanca, Spain, Jul 2014.
    
    % >> This function/class is part of the Nonlinear Estimation Toolbox
    %
    %    For more information, see https://bitbucket.org/nonlinearestimation/toolbox
    %
    %    Copyright (C) 2015  Jannik Steinbring <jannik.steinbring@kit.edu>
    %
    %                        Institute for Anthropomatics and Robotics
    %                        Chair for Intelligent Sensor-Actuator-Systems (ISAS)
    %                        Karlsruhe Institute of Technology (KIT), Germany
    %
    %                        http://isas.uka.de
    %
    %    This program is free software: you can redistribute it and/or modify
    %    it under the terms of the GNU General Public License as published by
    %    the Free Software Foundation, either version 3 of the License, or
    %    (at your option) any later version.
    %
    %    This program is distributed in the hope that it will be useful,
    %    but WITHOUT ANY WARRANTY; without even the implied warranty of
    %    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    %    GNU General Public License for more details.
    %
    %    You should have received a copy of the GNU General Public License
    %    along with this program.  If not, see <http://www.gnu.org/licenses/>.
    
    methods
        function obj = PGF(name)
            % Class constructor.
            %
            % Parameters:
            %   >> name (Char)
            %      An appropriate filter name / description of the implemented
            %      filter. The Filter subclass should set this during its
            %      construction to a meaningful default value (e.g., 'EKF'),
            %      or the user should specify an appropriate name (e.g., 
            %      'PF (10k Particles)').
            %
            %      Default name: 'PGF'.
            %
            % Returns:
            %   << obj (PGF)
            %      A new PGF instance.
            
            if nargin < 1
                name = 'PGF';
            end
            
            samplingPred = GaussianSamplingLCD();
            samplingUp   = GaussianSamplingLCD();
            
            % By default, determine the number of samples for prediction
            % and update by using a factor of 10.
            samplingPred.setNumSamplesByFactor(10);
            samplingUp.setNumSamplesByFactor(10);
            
            % Call superclass constructor
            obj = obj@SampleBasedJointlyGaussianPrediction(name, samplingPred);
            
            obj.samplingUpdate = samplingUp;
            
            obj.maxNumProgSteps = 0;
            obj.numProgSteps    = 0;
        end
        
        function setNumSamples(obj, numSamplesPrediction, numSamplesUpdate)
            % Set an absolute number of samples used by the PGF for prediction and upate.
            %
            % This overwrites a possible previous setting, where the number of samples
            % are determined by a linear factor (see setNumSamplesByFactor()).
            %
            % By default, a linear factor 10 is used for prediction and update.
            %
            % Parameters:
            %    >> numSamplesPrediction (Positive scalar)
            %       The new absolute number of samples used for the prediction.
            %
            %    >> numSamplesUpdate (Positive scalar)
            %       The new absolute number of samples used for the update.
            %       Default: the same number of samples specified for the prediction.
            
            obj.samplingPrediction.setNumSamples(numSamplesPrediction);
            
            if nargin == 3
                obj.samplingUpdate.setNumSamples(numSamplesUpdate);
            else
                obj.samplingUpdate.setNumSamples(numSamplesPrediction);
            end
        end
        
        function setNumSamplesByFactor(obj, factorPrediction, factorUpdate)
            % Set a linear factor to determine the number of samples used by the PGF for prediction and upate.
            %
            % The actual number of samples will be computed according to
            %
            %    Number of samples = factor * dimension
            %
            % This overwrites a possible previous setting, where the number of samples
            % are determined in an absolute way (see setNumSamples()).
            %
            % By default, a linear factor 10 is used for prediction and update.
            %
            % Parameters:
            %    >> factorPrediction (Positive scalar)
            %       The new linear factor to determine the number of samples for the prediction.
            %
            %    >> factorUpdate (Positive scalar)
            %       The new linear factor to determine the number of samples for the update.
            %       Default: the same factor specified for the prediction.
            
            obj.samplingPrediction.setNumSamplesByFactor(factorPrediction);
            
            if nargin == 3
                obj.samplingUpdate.setNumSamplesByFactor(factorUpdate);
            else
                obj.samplingUpdate.setNumSamplesByFactor(factorPrediction);
            end
        end
        
        function setMaxNumProgSteps(obj, maxNumProgSteps)
            % Set the maximum number of allowed progression steps.
            %
            % If a measurement update exceeds the maximum number of allowed
            % progression steps, the progression will be stopped and the
            % current intermediate Gaussian distribution will be set as the
            % posterior state estimate. This can be interpreted as not the
            % entire information of the given measurements were processed.
            %
            % A maximum number is useful when certain runtime conditions
            % have to be met, e.g., an update has to be performed within a
            % specified time.
            %
            % A value of zero means no maximum, and hence, the progression
            % will not be interrupted.
            %
            % By default, no maximum is set.
            %
            % Parameters:
            %   >> maxNumProgSteps (Scalar)
            %      The new maximum number of allowed progression steps.
            
            if ~Checks.isScalar(maxNumProgSteps)
                obj.error('InvalidMaximumNumberOfProgressionSteps', ...
                          'maxNumProgSteps must be a scalar.');
            end
            
            obj.maxNumProgSteps = ceil(maxNumProgSteps);
        end
        
        function maxNumProgSteps = getMaxNumProgSteps(obj)
            % Get the current maximum number of allowed progression steps.
            %
            % Returns:
            %   << maxNumProgSteps (Scalar)
            %      The current maximum number of allowed progression steps.
            
            maxNumProgSteps = obj.maxNumProgSteps;
        end
        
        function numProgSteps = getNumProgSteps(obj)
            % Get the number of progression steps required by the last measurement update.
            %
            % Returns:
            %   << numProgSteps (Non-negative scalar)
            %      The number of progression steps required by the last measurement update.
            
            numProgSteps = obj.numProgSteps;
        end
    end
    
    methods (Access = 'protected')
        % We overwrite the moment computations for the state prediction
        % in order to exploit the fact that all samples used by the LCD-based
        % Gaussian sampling are equally weighted. This reduces runtime and has
        % numerical benefits.
        
        function [predictedStateMean, ...
                  predictedStateCov] = predictedMomentsArbitraryNoise(obj, sysModel)
            [noiseMean, ~, noiseCovSqrt] = sysModel.noise.getMeanAndCov();
            
            % Generate state and noise samples
            % Keep in mind that we know that all samples are equally weighted
            [stateSamples, ...
             noiseSamples, ...
             ~, ...
             numSamples] = Utils.getStateNoiseSamples(obj.samplingPrediction, ...
                                                      obj.stateMean, obj.stateCovSqrt, ...
                                                      noiseMean, noiseCovSqrt);
            
            % Propagate samples through system equation
            predictedStates = sysModel.systemEquation(stateSamples, noiseSamples);
            
            % Check predicted state samples
            obj.checkPredictedStateSamples(predictedStates, numSamples);
            
            % Compute predicted state mean and covariance
            [predictedStateMean, ...
             predictedStateCov] = Utils.getMeanAndCov(predictedStates);
        end
        
        function [predictedStateMean, ...
                  predictedStateCov] = predictedMomentsAdditiveNoise(obj, sysModel)
            [noiseMean, noiseCov] = sysModel.noise.getMeanAndCov();
            dimNoise = size(noiseMean, 1);
            
            obj.checkAdditiveSysNoise(dimNoise);
            
            % Generate state samples
            % Keep in mind that we know that all samples are equally weighted
            [stateSamples, ...
             ~, ...
             numSamples] = Utils.getStateSamples(obj.samplingPrediction, ...
                                                 obj.stateMean, obj.stateCovSqrt);
            
            % Propagate samples through deterministic system equation
            predictedStates = sysModel.systemEquation(stateSamples);
            
            % Check predicted state samples
            obj.checkPredictedStateSamples(predictedStates, numSamples);
            
            [mean, cov] = Utils.getMeanAndCov(predictedStates);
            
            % Compute predicted state mean
            predictedStateMean = mean + noiseMean;
            
            % Compute predicted state covariance
            predictedStateCov = cov + noiseCov;
        end
        
        function [updatedMean, ...
                  updatedCov] = performUpdateObservable(obj, measModel, measurements, ...
                                                        priorMean, ~, priorCovSqrt)
            if Checks.isClass(measModel, 'Likelihood')
                [updatedMean, ...
                 updatedCov] = obj.updateLikelihood(measModel, measurements, ...
                                                    priorMean, priorCovSqrt);
            else
                obj.errorMeasModel('Likelihood');
            end
        end
        
        function [updatedMean, ...
                  updatedCov] = updateLikelihood(obj, measModel, measurements, ...
                                                 priorMean, priorCovSqrt)
            % Initialize progression
            dimState         = size(priorMean, 1);
            updatedMean      = priorMean;
            updatedCovSqrt   = priorCovSqrt;
            gamma            = 0;
            obj.numProgSteps = 0;
            
            % Get standard normal approximation
            [stdNormalSamples, ~, numSamples] = obj.samplingUpdate.getStdNormalSamples(dimState);
            
            % Set forced sample weight ratio
            logForcedRatio = -log(numSamples); % = log(1 / numSamples)
            
            % Start progression
            while gamma < 1 && (obj.maxNumProgSteps == 0 || obj.numProgSteps < obj.maxNumProgSteps)
                % Increment step counter
                obj.numProgSteps = obj.numProgSteps + 1;
                
                % Sample intermediate Gaussian approximation
                samples = updatedCovSqrt * stdNormalSamples;
                samples = bsxfun(@plus, samples, updatedMean);
                
                % Evaluate log likelihood
                logValues = measModel.logLikelihood(samples, measurements);
                
                obj.checkLogLikelihoodEvaluations(logValues, numSamples);
                
                % Compute deltaGamma
                
                % Discard zero likelihood values
                validLogValues = logValues(logValues > -Inf);
                
                if isempty(validLogValues)
                    obj.ignoreMeas('All likelihood values are zero.');
                end
                
                minLogValue = min(validLogValues);
                maxLogValue = max(validLogValues);
                
                if minLogValue == maxLogValue
                    obj.ignoreMeas('Minimum and maximum likelihood values are identical.');
                end
                
                deltaGamma = logForcedRatio / (minLogValue - maxLogValue);
                
                % Clamp deltaGamma if necessary
                if gamma + deltaGamma > 1
                    deltaGamma = 1 - gamma;
                    gamma = 1;
                else
                    gamma = gamma + deltaGamma;
                end
                
                % For numerical stability
                logValues = logValues - maxLogValue;
                
                % Compute intermediate posterior sample weights
                weights = exp(logValues * deltaGamma);
                
                % Normalize weights
                sumWeights = sum(weights);
                
                if sumWeights <= 0
                    obj.ignoreMeas('Sum of computed sample weights is not positive.');
                end
                
                weights = weights / sumWeights;
                
                % Compute new intermediate mean and covariance
                [updatedMean, updatedCov] = Utils.getMeanAndCov(samples, weights);
                
                if gamma ~= 1
                    % Check if intermediate state covariance matrix is valid
                    updatedCovSqrt = obj.checkCovUpdate(updatedCov, 'Intermediate state');
                end
            end
        end
    end
    
    methods (Access = 'protected')
        function cpObj = copyElement(obj)
            cpObj = obj.copyElement@SampleBasedJointlyGaussianPrediction();
            
            cpObj.samplingUpdate  = obj.samplingUpdate.copy();
            cpObj.maxNumProgSteps = obj.maxNumProgSteps;
            cpObj.numProgSteps    = obj.numProgSteps;
        end
    end
    
    properties (Access = 'private')
        % Gaussian LCD sampling used for the update.
        samplingUpdate;
        
        % The maximum number of allowed progression steps.
        maxNumProgSteps;
        
        % The number of progression steps required by the last measurement update.
        numProgSteps;
    end
end
