import { Router, type IRouter } from "express";
import healthRouter from "./health";
import wsUrlRouter from "./wsUrl";

const router: IRouter = Router();

router.use(healthRouter);
router.use(wsUrlRouter);

export default router;
