
/* >> This file is part of the Nonlinear Estimation Toolbox
 *
 *    For more information, see https://bitbucket.org/nonlinearestimation/toolbox
 *
 *    Copyright (C) 2015  Jannik Steinbring <jannik.steinbring@kit.edu>
 *                        Martin Pander <martin.pander@student.kit.edu>
 *
 *                        Institute for Anthropomatics and Robotics
 *                        Chair for Intelligent Sensor-Actuator-Systems (ISAS)
 *                        Karlsruhe Institute of Technology (KIT), Germany
 *
 *                        http://isas.uka.de
 *
 *    This program is free software: you can redistribute it and/or modify
 *    it under the terms of the GNU General Public License as published by
 *    the Free Software Foundation, either version 3 of the License, or
 *    (at your option) any later version.
 *
 *    This program is distributed in the hope that it will be useful,
 *    but WITHOUT ANY WARRANTY; without even the implied warranty of
 *    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *    GNU General Public License for more details.
 *
 *    You should have received a copy of the GNU General Public License
 *    along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef _GLCD_MCVM_DISTANCE_SYMMETRIC_EVEN_H_
#define _GLCD_MCVM_DISTANCE_SYMMETRIC_EVEN_H_

#include <GLCD/MCvMDistanceSym.h>

namespace GLCD {

class MCvMDistanceSymEven : public MCvMDistanceSym {
    public:
        MCvMDistanceSymEven(unsigned int dim,
                            unsigned int numHalfSamples);
        
        ~MCvMDistanceSymEven();
        
        Eigen::MatrixXd getSamples() const;
        
    protected:
        void computeD2(double& D2);
        
        void computeD3(double& D3);
        
        void computeGrad2(Eigen::MatrixXd& grad1);
        
};

}  // namespace GLCD

#endif
